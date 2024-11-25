import UIKit
import TKUIKit
import Stories
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListDevMenuConfigurator: SettingsListConfigurator {
  
  var didSelectRNWalletsSeedPhrases: (() -> Void)?

  // MARK: - SettingsListV2Configurator
  
  var title: String { "Dev Menu" }
  var isSelectable: Bool { false }
  var didUpdateState: ((SettingsListState) -> Void)?
  
  func getInitialState() -> SettingsListState {
    createState()
  }
  
  private let uniqueIdProvider: UniqueIdProvider
  private let storiesService: StoriesService
  
  init(uniqueIdProvider: UniqueIdProvider,
       storiesService: StoriesService) {
    self.uniqueIdProvider = uniqueIdProvider
    self.storiesService = storiesService
  }
  
  private func createState() -> SettingsListState {
    var sections = [SettingsListSection]()
    sections.append(createCacheSection())
    if let seedPhraseRecoverySection = createSeedPhraseRecoverySection() {
      sections.append(seedPhraseRecoverySection)
    }
    
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createSeedPhraseRecoverySection() -> SettingsListSection? {
    guard !UIApplication.shared.isAppStoreEnvironment else { return nil }
    let items = [
      createRNSeedPhrasesItem()
    ]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 0
    ))
  }
  
  private func createCacheSection() -> SettingsListSection {
    let items = [
      createResetWatchedStories()
    ]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 0
    ))
  }
  
  private func createRNSeedPhrasesItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: "Pre 5.0.0 seed phrases")
        )))
    return SettingsListItem(
      id: .version4SeedPhrasesIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { [weak self] _ in
        self?.didSelectRNWalletsSeedPhrases?()
      }
    )
  }
  
  private func createResetWatchedStories() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: "Reset watched stories")
        )))
    return SettingsListItem(
      id: .resetWatchedStoriesIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { [weak self] _ in
        self?.storiesService.resetShownStories()
        ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Reseted"))
      }
    )
  }
}

private extension String {
  static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
  static let resetWatchedStoriesIdentifier = "resetWatchedStoriesIdentifier"
  static let installIdIdentifier = "installIDIdentifier"
  static let privacyPolicyIdentifier = "privacyPolicyIdentifier"
  static let montserratFontIdentifier = "montserratFontIdentifier"
}
