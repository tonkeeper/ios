import UIKit
import TKUIKit
import KeeperCore
import CoreComponents
import TKLocalize
import TKCore

final class SettingsListRNWalletsSeedPhrasesConfigurator: SettingsListConfigurator {
  
  struct WalletItem: Equatable, Hashable {
    let name: String
    let identifier: String
  }

  // MARK: - SettingsListV2Configurator
  
  var title: String { "Seed phrases" }
  var isSelectable: Bool { false }
  var didUpdateState: ((SettingsListState) -> Void)?
  
  func getInitialState() -> SettingsListState {
    createState()
  }
  
  private let mnemonics: Mnemonics
  private let wallets: [WalletItem]
  
  init(mnemonics: Mnemonics, wallets: [WalletItem]) {
    self.mnemonics = mnemonics
    self.wallets = wallets
  }
  
  private func createState() -> SettingsListState {
    let sections = [
      createSeedPhraseRecoverySection()
    ]
    
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createSeedPhraseRecoverySection() -> SettingsListSection {
    let items = createSeedPhrasesItems()
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 0
    ))
  }
  
  private func createSeedPhrasesItems() -> [SettingsListItem] {
    let items = wallets.compactMap { wallet -> SettingsListItem? in
      guard let mnemonic = mnemonics[wallet.identifier] else {
        return nil
      }
      return createSeedPhrasesItem(mnemonic: mnemonic, label: wallet.name)
    }
    return items
  }
  
  private func createSeedPhrasesItem(mnemonic: Mnemonic, label: String) -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: label)
        )))
    return SettingsListItem(
      id: .version4SeedPhrasesIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .none,
      onSelection: { _ in
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        ToastPresenter.showToast(configuration: .copied)
        UIPasteboard.general.string = mnemonic.mnemonicWords.joined(separator: ",")
      }
    )
  }
}

private extension String {
  static let version4SeedPhrasesIdentifier = "version4SeedPhrasesIdentifier"
}
