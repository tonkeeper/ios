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
    let title: String
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
    if let app = apps[safe: 0] {
      didSelectDapp?(app)
    } else if let suggestion = searchSuggestions[safe: 0],
              let dapp = composeDapp(suggestion) {
      didSelectDapp?(dapp)
    }
  }
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, TKUIListItemCell.Configuration>()
  private var apps = [Dapp]()
  private var searchSuggestions = [SearchEngineSuggestion]()
  private var suggestionTask: Task<(), Error>?

  // MARK: - Dependencies
  
  private let popularAppsService: PopularAppsService
  private let searchEngineStore: SearchEngineStore
  private let searchEngineService: SearchEngineServiceProtocol

  // MARK: - Init
  
  init(popularAppsService: PopularAppsService,
       searchEngineStore: SearchEngineStore,
       searchEngineService: SearchEngineServiceProtocol) {
    self.popularAppsService = popularAppsService
    self.searchEngineStore = searchEngineStore
    self.searchEngineService = searchEngineService
  }
}

private extension BrowserSearchViewModelImplementation {

  func searchPopularApps(input: String) {
    snapshot.deleteAllItems()

    guard !input.isEmpty else {
      apps = [Dapp]()
      searchSuggestions = [SearchEngineSuggestion]()

      didUpdateSnapshot?(snapshot)
      return
    }

    let lang = Locale.current.languageCode ?? "en"
    if let popularApps = try? popularAppsService.getPopularApps(lang: lang) {
      let filtered = popularApps.categories
        .flatMap { $0.apps }
        .filter { $0.name.contains(input) }
        .prefix(3)
      apps = Array(filtered)
      let items = apps.map { mapDapp($0) }

      snapshot.appendSections([.apps])
      snapshot.appendItems(items, toSection: .apps)
      didUpdateSnapshot?(snapshot)
    }

    suggestionTask?.cancel()
    suggestionTask = Task {
      let suggesstions = try await searchEngineService.loadSuggestions(
        searchText: input,
        searchEngine: searchEngineStore.initialState)
        .prefix(4)

      guard !Task.isCancelled, !suggesstions.isEmpty else { return }

      let headerModel = BrowserSearchListSectionHeaderView.Model(
        titleModel: TKListTitleView.Model(
          title: searchEngineStore.initialState.searchTitle,
          textStyle: .label1
        )
      )
      let searchEngineResult = mapSearchEngineResult(input: input, items: Array(suggesstions))
      snapshot.appendSections([.newSearch(headerModel: headerModel)])
      snapshot.appendItems(searchEngineResult.cellModels, toSection: .newSearch(headerModel: headerModel))
      searchSuggestions = searchEngineResult.models

      await MainActor.run {
        didUpdateSnapshot?(snapshot)
      }
    }
  }
  
  private func mapDapp(_ dapp: Dapp) -> TKUIListItemCell.Configuration {
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

    let image = TKUIListItemImageIconView.Configuration.Image.asyncImage(dapp.icon, imageDownloadTask)
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: image,
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

  func mapSearchEngineResult(input: String, items: [String]) -> (models: [SearchEngineSuggestion], cellModels: [TKUIListItemCell.Configuration]) {
    guard !items.isEmpty else {
      return ([], [])
    }

    let items = items.compactMap {
      SearchEngineSuggestion(
        title: $0,
        url: searchEngineService.composeSearchURL(input: $0, searchEngine: searchEngineStore.initialState)
      )
    }

    var resultItems = [TKUIListItemCell.Configuration]()
    let mappedResult: [TKUIListItemCell.Configuration] = items.compactMap {
      return mapSuggestion($0)
    }
    resultItems.append(contentsOf: mappedResult)
    return (items, resultItems)
  }

  func mapSuggestion(_ suggestion: SearchEngineSuggestion) -> TKUIListItemCell.Configuration {
    let id = UUID().uuidString

    let title = suggestion.title
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
      name: suggestion.title,
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
