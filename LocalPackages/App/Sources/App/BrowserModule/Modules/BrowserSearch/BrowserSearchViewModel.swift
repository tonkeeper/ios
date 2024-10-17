import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

typealias BrowserSearchSnapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>

protocol BrowserSearchModuleOutput: AnyObject {
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserSearchViewModel: AnyObject {
  var didUpdateEmptyText: ((NSAttributedString) -> Void)? { get set }
  var didUpdateSnapshot: ((BrowserSearchSnapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func searchInput(_ input: String)
  func goButtonPressed()
}

final class BrowserSearchViewModelImplementation: BrowserSearchViewModel, BrowserSearchModuleOutput {

  struct SearchEngineSuggestion: Equatable {
    let title: String?
    let url: URL?
  }

  var didSelectDapp: ((Dapp) -> Void)?
  
  var didUpdateEmptyText: ((NSAttributedString) -> Void)?
  var didUpdateSnapshot: ((BrowserSearchSnapshot) -> Void)?
  
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
  
  func goButtonPressed() {
    if let validUrlSuggestion, let dapp = composeDapp(validUrlSuggestion) {
      didSelectDapp?(dapp)
    } else if let app = apps[safe: 0] {
      didSelectDapp?(app)
    } else if let suggestion = searchSuggestions[safe: 0],
              let dapp = composeDapp(suggestion) {
      didSelectDapp?(dapp)
    }
  }
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State

  typealias Snapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>
  private var snapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>()

  private var validUrlSuggestion: SearchEngineSuggestion? {
    didSet {
      DispatchQueue.main.async { self.updateSnapshot() }
    }
  }
  private var apps = [Dapp]() {
    didSet {
      DispatchQueue.main.async { self.updateSnapshot() }
    }
  }

  private var syncQueue = DispatchQueue(label: #function)
  private var _searchSuggestions = [SearchEngineSuggestion]()
  private var searchSuggestions: [SearchEngineSuggestion] {
    get {
      return syncQueue.sync {
        _searchSuggestions
      }
    }
    set {
      syncQueue.sync {
        self._searchSuggestions = newValue

        DispatchQueue.main.async { self.updateSnapshot() }
      }
    }
  }
  private var suggestionTask: Task<(), Error>?

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
    defer {
      self.didUpdateSnapshot?(self.snapshot)
    }

    var snapshot = Snapshot()

    if !apps.isEmpty || validUrlSuggestion != nil {
      snapshot.appendSections([.apps])
    }

    if let validUrlSuggestion {
      let item = mapValidURLSuggestion(suggestion: validUrlSuggestion)
      snapshot.appendItems([item], toSection: .apps)
    }

    if !apps.isEmpty {
      let items = apps.map { mapDapp($0) }
      snapshot.appendItems(items, toSection: .apps)
    }

    if !searchSuggestions.isEmpty {
      let headerModel = BrowserSearchListSectionHeaderView.Model(
        titleModel: TKListTitleView.Model(
          title: appSettingsStore.initialState.searchEngine.searchTitle,
          textStyle: .label1
        )
      )
      let models = searchSuggestions.compactMap { mapSuggestion($0) }
      snapshot.appendSections([.newSearch(headerModel: headerModel)])
      snapshot.appendItems(models, toSection: .newSearch(headerModel: headerModel))
    }
    self.snapshot = snapshot
  }

  func searchPopularApps(input: String) {
    guard !input.isEmpty else {
      apps = [Dapp]()
      suggestionTask?.cancel()
      searchSuggestions = [SearchEngineSuggestion]()
      validUrlSuggestion = nil
      return
    }

    let lang = Locale.current.languageCode ?? "en"
    if let popularApps = try? popularAppsService.getPopularApps(lang: lang) {
      let filtered = popularApps.categories
        .flatMap { $0.apps }
        .filter { $0.name.contains(input) || $0.url.absoluteString.contains(input) }
        .prefix(3)
      self.apps = Array(filtered)
    }

    suggestionTask?.cancel()
    suggestionTask = Task {
      if input.isValidURL, let inputURL = URL(string: input) {
        validUrlSuggestion = .init(title: nil, url: inputURL)
        //-wait for parse title and compose url-//

        if !Task.isCancelled, let searchEngineTitle = await searchEngineService.parseTitleFrom(stringURL: input) {
          validUrlSuggestion = .init(title: searchEngineTitle.title, url: searchEngineTitle.url)
        }
      } else {
        validUrlSuggestion = nil
      }

      let searchEngine = appSettingsStore.initialState.searchEngine
      let suggestions = try await searchEngineService.loadSuggestions(
        searchText: input,
        searchEngine: searchEngine)
        .prefix(4)

      guard !Task.isCancelled, !suggestions.isEmpty else { return }

      searchSuggestions = suggestions.compactMap {
        SearchEngineSuggestion(
          title: $0,
          url: searchEngineService.composeSearchURL(input: $0, searchEngine: searchEngine)
        )
      }
    }
  }

  func mapValidURLSuggestion(suggestion: SearchEngineSuggestion) -> TKUIListItemCell.Configuration {
    let id = UUID().uuidString
   
    let title = suggestion.title ?? TKLocales.Browser.Search.openLinkPlaceholder
    let subtitle = suggestion.url?.absoluteString.withTextStyle(.body2, color: .Text.secondary)
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: title.withTextStyle(.label1, color: .Text.primary),
        tagViewModel: nil,
        subtitle: subtitle,
        description: nil
      ),
      rightItemConfiguration: nil
    )

    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .image(.TKUIKit.Icons.Size16.linkSmall),
            tintColor: .Icon.secondary,
            backgroundColor: .Background.contentAttention,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 12
          )
        ),
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )

    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        guard let self, let dapp = composeDapp(suggestion) else {
          return
        }
        self.didSelectDapp?(dapp)
      }
    )
  }

  func mapDapp(_ dapp: Dapp, icon: UIImage? = nil) -> TKUIListItemCell.Configuration {
    let id = UUID().uuidString
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: dapp.name.withTextStyle(.label1, color: .Text.primary),
        tagViewModel: nil,
        subtitle: dapp.url.absoluteString.withTextStyle(.body2, color: .Text.secondary),
        description: nil
      ),
      rightItemConfiguration: nil
    )

    let imageDownloadTask = TKCore.ImageDownloadTask() { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: dapp.icon,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }

    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .asyncImage(dapp.icon, imageDownloadTask),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 16
          )
        ),
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )

    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        self?.didSelectDapp?(dapp)
      }
    )
  }

  func mapSuggestion(_ suggestion: SearchEngineSuggestion) -> TKUIListItemCell.Configuration {
    let id = UUID().uuidString

    let title = suggestion.title?
      .withTextStyle(
        .label1,
        color: .Text.primary
      )
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: nil
    )
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: nil
    )

    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: .image(.TKUIKit.Icons.Size16.magnifyingGlass),
          tintColor: .Icon.secondary,
          backgroundColor: .clear,
          size: CGSize(width: 16, height: 16),
          cornerRadius: 0
        )
      ),
      alignment: .center
    )
    let listConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none)
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listConfiguration,
      selectionClosure: { [weak self] in
        guard let dapp = self?.composeDapp(suggestion) else {
          return
        }
        self?.didSelectDapp?(dapp)
      }
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
