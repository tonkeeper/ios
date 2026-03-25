import CoreComponents
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListRNWalletsSeedPhrasesConfigurator: SettingsListConfigurator {
    // MARK: - SettingsListV2Configurator

    var title: String {
        "Seed phrases"
    }

    var isSelectable: Bool {
        false
    }

    var didUpdateState: ((SettingsListState) -> Void)?

    func getInitialState() -> SettingsListState {
        createState()
    }

    private let mnemonics: Mnemonics

    init(mnemonics: Mnemonics) {
        self.mnemonics = mnemonics
    }

    private func createState() -> SettingsListState {
        let sections = [
            createSeedPhraseRecoverySection(),
        ]

        return SettingsListState(
            sections: sections
        )
    }

    private func createSeedPhraseRecoverySection() -> SettingsListSection {
        let items = createSeedPhrasesItems()
        return SettingsListSection.listItems(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createSeedPhrasesItems() -> [SettingsListItem] {
        return mnemonics.values.compactMap { mnemonic -> SettingsListItem? in
            return createSeedPhrasesItem(mnemonic: mnemonic, label: UUID().uuidString)
        }
    }

    private func createSeedPhrasesItem(mnemonic: Mnemonic, label: String) -> SettingsListItem {
        let cellConfiguration = TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: label)
                )
            )
        )
        return SettingsListItem(
            id: UUID().uuidString,
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
