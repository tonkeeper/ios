import UIKit
import TKUIKit
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
  
  init(uniqueIdProvider: UniqueIdProvider) {
    self.uniqueIdProvider = uniqueIdProvider
  }
  
  private func createState() -> SettingsListState {
    var sections = [SettingsListSection]()
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
}

private extension String {
  static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
  static let installIdIdentifier = "installIDIdentifier"
  static let privacyPolicyIdentifier = "privacyPolicyIdentifier"
  static let montserratFontIdentifier = "montserratFontIdentifier"
}
