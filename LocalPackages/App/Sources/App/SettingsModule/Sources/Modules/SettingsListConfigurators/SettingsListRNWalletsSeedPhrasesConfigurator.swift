import Foundation
import KeeperCore
import KeeperCoreComponents
import TKCore
import TKLocalize
import TKUIKit

final class SettingsListRNWalletsSeedPhrasesConfigurator: SettingsListConfigurator {
    // MARK: - SettingsListConfigurator

    var title: String {
        "Seed phrases"
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
        SettingsListState(
            sections: [
                createSeedPhraseRecoverySection(),
            ]
        )
    }

    private func createSeedPhraseRecoverySection() -> SettingsListSection {
        let items = createSeedPhrasesItems()
        return .items(SettingsListItemsSection(
            items: items.map(SettingsListItemsSectionItem.listItem)
        ))
    }

    private func createSeedPhrasesItems() -> [SettingsListItem] {
        mnemonics.values.map { mnemonic in
            createSeedPhrasesItem(mnemonic: mnemonic, label: UUID().uuidString)
        }
    }

    private func createSeedPhrasesItem(mnemonic: Mnemonic, label: String) -> SettingsListItem {
        SettingsListItem(
            id: UUID().uuidString,
            title: SettingsListItemTitle(label),
            onTap: { _ in
                Pasteboard.copySensitive(value: mnemonic.mnemonicWords.joined(separator: ","))
            }
        )
    }
}
