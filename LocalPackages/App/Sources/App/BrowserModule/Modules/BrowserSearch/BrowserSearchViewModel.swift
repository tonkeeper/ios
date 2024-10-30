import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserSearchModuleOutput: AnyObject {
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserSearchViewModel: AnyObject {
  var didUpdateEmptyText: ((NSAttributedString) -> Void)? { get set }
  var didUpdateSnapshot: ((BrowserSearch.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func searchInput(_ input: String)
}

final class BrowserSearchViewModelImplementation: BrowserSearchViewModel, BrowserSearchModuleOutput {

  struct SearchEngineSuggestion: Equatable {
    let title: String?
    let url: URL?
  }

  var didSelectDapp: ((Dapp) -> Void)?
  
  var didUpdateEmptyText: ((NSAttributedString) -> Void)?
  var didUpdateSnapshot: ((BrowserSearch.Snapshot) -> Void)?
  
  func viewDidLoad() {
    let emptyText = TKLocales.Browser.Search.placeholder
      .withTextStyle(
        .body1,
        color: .Text.tertiary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    didUpdateEmptyText?(emptyText)
  }
  
  func searchInput(_ input: String) {
    searchPopularApps(input: input)
  }

  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State
  
  private var urlSuggestion: SearchEngineSuggestion? {
    didSet {
      updateSnapshot()
    }
  }
  private var dapps = [Dapp]() {
    didSet {
      updateSnapshot()
    }
  }
  private var searchSuggestions =  [SearchEngineSuggestion]() {
    didSet {
      updateSnapshot()
    }
  }
  
  private var suggestionsTask: Task<(), Error>?
  private var cachedMetaData = [URL: String]()

  // MARK: - Dependencies
  
  private let popularAppsService: PopularAppsService
  private let appSettingsStore: AppSettingsStore
  private let searchEngineService: SearchEngineServiceProtocol

  // MARK: - Init
  
  init(popularAppsService: PopularAppsService,
       appSettingsStore: AppSettingsStore,
       searchEngineService: SearchEngineServiceProtocol) {
    self.popularAppsService = popularAppsService
    self.appSettingsStore = appSettingsStore
    self.searchEngineService = searchEngineService
  }
}

private extension BrowserSearchViewModelImplementation {

  func updateSnapshot() {
    var snapshot = BrowserSearch.Snapshot()
    
    if !dapps.isEmpty || urlSuggestion != nil {
      snapshot.appendSections([.dapps])
    }
    
    if let urlSuggestion {
      let identifier: String = .suggestURLIdentifier + (urlSuggestion.url?.absoluteString ?? "") + (urlSuggestion.title ?? "")
      let item = BrowserSearch.Item(
        identifier: identifier,
        configuration: mapValidURLSuggestion(suggestion: urlSuggestion),
        isHighlighted: true,
        onSelection: { [weak self] in
          guard let self, let dapp = composeDapp(urlSuggestion) else { return }
          didSelectDapp?(dapp)
        }
      )
      snapshot.appendItems([item], toSection: .dapps)
    }
    
    if !dapps.isEmpty {
      let items = dapps.map { dapp in
        return BrowserSearch.Item(
          identifier: dapp.url.absoluteString,
          configuration: mapDapp(dapp),
          isHighlighted: false) { [weak self] in
        self?.didSelectDapp?(dapp)
      }}
      snapshot.appendItems(items, toSection: .dapps)
    }
    
    if !searchSuggestions.isEmpty {
      let headerModel = BrowserSearchListSectionHeaderView.Model(
        titleModel: TKListTitleView.Model(
          title: appSettingsStore.state.searchEngine.searchTitle,
          textStyle: .label1
        )
      )
      let section = BrowserSearch.Section.suggests(headerModel: headerModel)
      
      snapshot.appendSections([section])
      snapshot.appendItems(searchSuggestions.compactMap { suggest -> BrowserSearch.Item? in
        guard let url = suggest.url else { return nil }
        return BrowserSearch.Item(identifier: url.absoluteString,
                                  configuration: mapSuggestion(suggest),
                                  isHighlighted: false,
                                  onSelection: { [weak self] in
          guard let self, let dapp = composeDapp(suggest) else { return }
          didSelectDapp?(dapp)
        })
      }, toSection: section)
    }
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    didUpdateSnapshot?(snapshot)
  }

  func searchPopularApps(input: String) {
    guard !input.isEmpty else {
      dapps = [Dapp]()
      suggestionsTask?.cancel()
      searchSuggestions = [SearchEngineSuggestion]()
      urlSuggestion = nil
      return
    }

    let lang = Locale.current.languageCode ?? "en"
    if let popularApps = try? popularAppsService.getPopularApps(lang: lang) {
      let filtered = popularApps.categories
        .flatMap { $0.apps }
        .filter { $0.name.contains(input) || $0.url.absoluteString.contains(input) }
        .removingDuplicatedElements()
        .prefix(3)
      self.dapps = Array(filtered)
    }

    suggestionsTask?.cancel()
    suggestionsTask = Task { [weak self] in
      guard let self else { return }
      
      async let searchSuggestionsTask: () = searchSuggestions(input: input)
      async let searchSuggestURLTask: () = searchSuggestURL(input: input)
      
      await searchSuggestionsTask
      await searchSuggestURLTask
    }
  }

  func searchSuggestURL(input: String) async {
    guard let urlInput = updateURLInput(input: input),
    urlInput.isValidURL else {
      await MainActor.run {
        self.urlSuggestion = nil
      }
      return
    }

    let needLoadMeta = await MainActor.run {
      if let cachedTitle = cachedMetaData[urlInput] {
        self.urlSuggestion = .init(title: cachedTitle, url: urlInput)
        return false
      } else {
        self.urlSuggestion = .init(title: nil, url: urlInput)
        return true
      }
    }
    guard needLoadMeta else {
      return
    }
    guard let searchEngineMeta = await searchEngineService.parseMetaFrom(url: urlInput) else { return }
    guard !Task.isCancelled else { return }
    await MainActor.run {
      cachedMetaData[urlInput] = searchEngineMeta.title
      self.urlSuggestion = .init(title: searchEngineMeta.title, url: urlInput)
    }
  }
  
  func searchSuggestions(input: String) async {
    try? await Task.sleep(nanoseconds: 500_000_000)
    guard !Task.isCancelled else { return }
    let searchEngine = appSettingsStore.state.searchEngine
    do {
      let suggestions = try await searchEngineService.loadSuggestions(
        searchText: input,
        searchEngine: searchEngine)
        .removingDuplicates()
        .prefix(4)
      guard !Task.isCancelled else { return }
      
      await MainActor.run {
        self.searchSuggestions = suggestions.compactMap {
          SearchEngineSuggestion(
            title: $0,
            url: self.searchEngineService.composeSearchURL(input: $0, searchEngine: searchEngine)
          )
        }
      }
    } catch {
      await MainActor.run {
        self.searchSuggestions = []
      }
    }
  }

  func mapValidURLSuggestion(suggestion: SearchEngineSuggestion) -> TKListItemCell.Configuration {
    let title = suggestion.title ?? TKLocales.Browser.Search.openLinkPlaceholder
    let caption = suggestion.url?.absoluteString
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: TKListItemIconView.Configuration(
          content: .image(TKImageView.Model(image: .image(.TKUIKit.Icons.Size16.linkSmall),
                                            tintColor: .Icon.secondary,
                                            size: .auto)),
          alignment: .center,
          cornerRadius: 12,
          backgroundColor: .Background.contentAttention,
          size: CGSize(width: 44, height: 44)
        ),
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: title
          ),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(
              text: caption,
              color: .Text.secondary,
              textStyle: .body2)
          ]
        )
      )
    )
  }

  func mapDapp(_ dapp: Dapp) -> TKListItemCell.Configuration {
    TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: TKListItemIconView.Configuration(
          content: .image(TKImageView.Model(image: .urlImage(dapp.icon), size: .size(CGSize(width: 44, height: 44)), corners: .cornerRadius(cornerRadius: 12))),
          alignment: .center,
          cornerRadius: 12,
          backgroundColor: .clear,
          size: CGSize(width: 44, height: 44)
        ),
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: dapp.name
          ),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(
              text: dapp.url.absoluteString,
              color: .Text.secondary,
              textStyle: .body2)
          ]
        )
      )
    )
  }
  
  func mapSuggestion(_ suggestion: SearchEngineSuggestion) -> TKListItemCell.Configuration {
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: TKListItemIconView.Configuration(
          content: .image(TKImageView.Model(image: .image(.TKUIKit.Icons.Size16.magnifyingGlass),
                                            tintColor: .Icon.secondary,
                                            size: .auto)),
          alignment: .center,
          backgroundColor: .clear,
          size: CGSize(width: 16, height: 16)
        ),
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: suggestion.title?.withTextStyle(.label2, color: .Text.primary), numberOfLines: 1)
        )
      )
    )
  }

  private func composeDapp(_ suggestion: SearchEngineSuggestion) -> Dapp? {
    guard let url = suggestion.url else {
      return nil
    }
    let dapp = Dapp(
      name: suggestion.title ?? "",
      description: nil,
      icon: nil,
      poster: nil,
      url: url,
      textColor: nil,
      excludeCountries: nil,
      includeCountries: nil
    )
    return dapp
  }
  
  private func updateURLInput(input: String) -> URL? {
    let httpsPrefix = "https://"
    let httpPrefix = "http://"
    var input = input
    if !input.hasPrefix(httpsPrefix) && !input.hasPrefix(httpPrefix) {
      input = httpsPrefix + input
    }
    return URL(string: input)
  }
}

extension SearchEngine {

  public var searchTitle: String {
    switch self {
    case .duckduckgo:
      TKLocales.Browser.Search.DuckgoSearch.title
    case .google:
      TKLocales.Browser.Search.GoogleSearch.title
    }
  }
}

extension URL {
  var isValidURL: Bool {
    absoluteString.isValidURL
  }
}

extension String {
  var isValidURL: Bool {
    guard let url = URL(string: self) else { return false }
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
    let host = components.host else { return false }
    return host.components(separatedBy: ".").filter { !$0.isEmpty }.count > 1
  }
}

private extension String {
  static let suggestURLIdentifier = "SuggestURLIdentifier"
}

private extension Array where Element: Hashable {
  func removingDuplicates() -> [Element] {
    var addedDict = [Element: Bool]()
    
    return filter {
      addedDict.updateValue(true, forKey: $0) == nil
    }
  }
  
  mutating func removeDuplicates() {
    self = self.removingDuplicates()
  }
}
