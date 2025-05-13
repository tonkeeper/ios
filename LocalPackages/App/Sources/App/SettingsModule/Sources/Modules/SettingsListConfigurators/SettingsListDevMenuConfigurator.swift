import UIKit
import WebKit
import TKUIKit
import Stories
import KeeperCore
import TKLocalize
import TKCore
import TKFeatureFlags
import TKAppInfo

final class SettingsListDevMenuConfigurator: SettingsListConfigurator {
  
  var didSelectRNSeedPhrasesRecovery: (() -> Void)?
  var didSelectSeedPhrasesRecovery: (() -> Void)?

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
    
    sections.append(createConfirmationSection())
    
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createSeedPhraseRecoverySection() -> SettingsListSection? {
    guard !UIApplication.shared.isAppStoreEnvironment else { return nil }
    let items = [
      createRNSeedPhrasesItem(),
      createSeedPhraseRecoveryItem()
    ]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items
    ))
  }
  
  private func createCacheSection() -> SettingsListSection {
    let items = [
      createResetWatchedStories()
    ]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items
    ))
  }

  private func createRNSeedPhrasesItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: "Pre 5.0.0 seed phrases recovery")
        )))
    return SettingsListItem(
      id: .version4SeedPhrasesIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { [weak self] _ in
        self?.didSelectRNSeedPhrasesRecovery?()
      }
    )
  }
  
  private func createSeedPhraseRecoveryItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: "5 version seed phrases recovery")
        )))
    return SettingsListItem(
      id: .version5SeedPhrasesIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { [weak self] _ in
        self?.didSelectSeedPhrasesRecovery?()
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
  
  private func clearCookiesItem() -> SettingsListItem {

    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: "Clear cookies"
          )
        )
      )
    )
    return SettingsListItem(
      id: .clearCookiesItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { _ in
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        print("[WebCacheCleaner] All cookies deleted")
        
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
          records.forEach { record in
            WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            print("[WebCacheCleaner] Record \(record) deleted")
          }
        }
      }
    )
  }
  
  private func createConfirmationSection() -> SettingsListSection {
    return SettingsListSection.listItems(
      SettingsListItemsSection(
        items: [createConfirmationSliderItem()],
        headerConfiguration: SettingsListSectionHeaderView.Configuration(title: "Confirmation")
      )
    )
  }
  
  private func createConfirmationSliderItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: "Slider"
          )
        )
      )
    )
    
    let isOn = !TKFeatureFlags.localProvider.isConfirmButtonInsteadSlider
    let action: (Bool) -> Void = { isOn in
      TKFeatureFlags.localProvider.isConfirmButtonInsteadSlider = !isOn
    }
    
    return SettingsListItem(
      id: .confirmationSliderItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .switch(
        TKListItemSwitchAccessoryView.Configuration(
          isOn: isOn,
          isEnable: true,
          action: { isEnabled in
            action(isEnabled)
          }
        )
      ),
      onSelection: { [weak self] _ in
        guard let self else { return }
        action(!isOn)
        let state = self.createState()
        self.didUpdateState?(state)
      }
    )
  }
}

private extension String {
  static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
  static let version5SeedPhrasesIdentifier = "version5SeedPhrasesIdentifier"
  static let resetWatchedStoriesIdentifier = "resetWatchedStoriesIdentifier"
  static let clearCookiesItemIdentifier = "clearCookiesItemIdentifier"
  static let confirmationSliderItemIdentifier = "confirmationSliderItemIdentifier"
}
