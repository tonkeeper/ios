import KeeperCore
import SwiftUI
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

/// The Ledger a wallet is paired with: the wallets of its accounts with their networks, adding networks to this
/// wallet, and checking that the Ledger answers and holds it.
final class SettingsListLedgerDeviceConfigurator: SettingsListConfigurator {
    var didTapAddNetworks: ((Wallet) -> Void)?
    var didTapCheckConnection: ((Wallet) -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.LedgerDevice.title
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    // MARK: - Dependencies

    private var wallet: Wallet
    private let walletsStore: WalletsStore
    private let featureFlags: TKFeatureFlags

    // MARK: - Init

    init(wallet: Wallet, walletsStore: WalletsStore, featureFlags: TKFeatureFlags) {
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.featureFlags = featureFlags
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didAddWallets, .didDeleteWallet, .didUpdateWalletMetaData, .didUpdateWalletMultichain:
                DispatchQueue.main.async {
                    observer.wallet = observer.walletsStore.getWallet(id: observer.wallet.id) ?? observer.wallet
                    observer.didUpdateState?(observer.createState())
                }
            default:
                break
            }
        }
    }
}

private extension SettingsListLedgerDeviceConfigurator {
    func createState() -> SettingsListState {
        guard case let .Ledger(_, _, device) = wallet.identity.kind else {
            return SettingsListState(sections: [])
        }
        let accounts = walletsStore.wallets
            .compactMap { wallet -> (wallet: Wallet, account: Int16)? in
                guard case let .Ledger(_, _, walletDevice) = wallet.identity.kind, walletDevice.deviceId == device.deviceId else {
                    return nil
                }
                return (wallet, walletDevice.accountIndex)
            }
            .sorted { $0.account < $1.account }
        return SettingsListState(sections: [
            .items(SettingsListItemsSection(
                items: accounts.map { .listItem(createAccountItem(wallet: $0.wallet, account: $0.account)) },
                header: SettingsListSectionHeader(title: device.deviceModel, caption: TKLocales.LedgerDevice.wallets)
            )),
            .items(SettingsListItemsSection(items: createActionItems().map(SettingsListItemsSectionItem.listItem))),
        ])
    }

    func createAccountItem(wallet: Wallet, account: Int16) -> SettingsListItem {
        let chains = wallet.multichainWalletState.map { state in
            MultichainChain.displayOrder.filter { chain in state.addresses.contains { $0.chain == chain } }
        } ?? [.ton]
        return SettingsListItem(
            id: wallet.id,
            icon: SettingsListItemIcon(wallet: wallet),
            title: SettingsListItemTitle(wallet.label),
            captions: [
                SettingsListItemCaption(TKLocales.LedgerDevice.account(Int(account) + 1)),
                SettingsListItemCaption(chains.map(\.shortDisplayTitle).joined(separator: ", ")),
            ]
        )
    }

    func createActionItems() -> [SettingsListItem] {
        var items = [SettingsListItem]()
        let chains = wallet.addableLedgerChains(featureFlags: featureFlags)
        if !chains.isEmpty {
            items.append(SettingsListItem(
                id: .addNetworksIdentifier,
                title: SettingsListItemTitle(TKLocales.Settings.Items.addLedgerNetworks),
                captions: [SettingsListItemCaption(chains.map(\.shortDisplayTitle).joined(separator: ", "))],
                accessory: .icon(.TKUIKit.Icons.Size28.plusCircle, tintColor: .accentBlue),
                onTap: { [weak self] _ in
                    guard let self else { return }
                    self.didTapAddNetworks?(self.wallet)
                }
            ))
        }
        items.append(SettingsListItem(
            id: .checkConnectionIdentifier,
            title: SettingsListItemTitle(TKLocales.LedgerDevice.checkConnection),
            captions: [SettingsListItemCaption(TKLocales.LedgerDevice.checkConnectionCaption)],
            accessory: .icon(.TKUIKit.Icons.Size28.ledger, tintColor: .accentBlue),
            onTap: { [weak self] _ in
                guard let self else { return }
                self.didTapCheckConnection?(self.wallet)
            }
        ))
        return items
    }
}

private extension String {
    static let addNetworksIdentifier = "addNetworksIdentifier"
    static let checkConnectionIdentifier = "checkConnectionIdentifier"
}
