import UIKit
import TKUIKit
import Stories
import KeeperCore
import TKLocalize
import TKCore
import TKFeatureFlags

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
    sections.append(createSwapSection())
    
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
      topPadding: 16,
      bottomPadding: 0
    ))
  }
  
  private func createSwapSection() -> SettingsListSection {
    let items = [
      createSwapURLItem()
    ]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 16,
      bottomPadding: 0,
      headerConfiguration: SettingsListSectionHeaderView.Configuration(
        title: "Swap"
      )
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
  
  private func createSwapURLItem() -> SettingsListItem {

    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: "Tonkeeper Swap"
          )
        )
      )
    )

    let isTonkeeperSwapOn = TKFeatureFlags.localProvider.isTonkeeperSwapOn
    let isEnabled = isTonkeeperSwapOn
    let action: (Bool) -> Void = { isOn in
      TKFeatureFlags.localProvider.isTonkeeperSwapOn = isOn
    }

    return SettingsListItem(
      id: .swapURLItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .switch(
        TKListItemSwitchAccessoryView.Configuration(
          isOn: isTonkeeperSwapOn,
          isEnable: true,
          action: { isEnabled in
            action(isEnabled)
          }
        )
      ),
      onSelection: { [weak self] _ in
        guard let self else { return }
        action(!isEnabled)
        let state = self.createState()
        self.didUpdateState?(state)
      }
    )
  }
}

private extension String {
  static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
  static let resetWatchedStoriesIdentifier = "resetWatchedStoriesIdentifier"
  static let swapURLItemIdentifier = "swapURLItemIdentifier"
}
