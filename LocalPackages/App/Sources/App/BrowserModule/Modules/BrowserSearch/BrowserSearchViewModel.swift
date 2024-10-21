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

  // MARK: - Dependencies
  
  private let popularAppsService: PopularAppsService
  private let appSettingsStore: AppSettingsV3Store
  private let searchEngineService: SearchEngineServiceProtocol

  // MARK: - Init
  
  init(popularAppsService: PopularAppsService,
       appSettingsStore: AppSettingsV3Store,
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
      let item = BrowserSearch.Item(
        identifier: .suggestURLIdentifier,
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
          title: appSettingsStore.initialState.searchEngine.searchTitle,
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
      if input.isValidURL, let inputURL = URL(string: input) {
        await MainActor.run {
          self.urlSuggestion = .init(title: nil, url: inputURL)
        }
        //-wait for parse title and compose url-//

        if !Task.isCancelled, let searchEngineTitle = await searchEngineService.parseTitleFrom(stringURL: input) {
          await MainActor.run {
            self.urlSuggestion = .init(title: searchEngineTitle.title, url: searchEngineTitle.url)
          }
        }
      } else {
        await MainActor.run {
          self.urlSuggestion = nil
        }
      }

      let searchEngine = await appSettingsStore.getState().searchEngine
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


extension String {

  var isValidURL: Bool {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    if let match = detector?.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
      // it is a link, if the match covers the whole string
      return match.range.length == self.utf16.count
    } else {
      return false
    }
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
