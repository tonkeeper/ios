import AppUI
import KeeperCore
import TKUIKit
import UIKit

struct BatteryRefillSupportedTransactionsAssembly {
    private init() {}

    @MainActor
    static func module(
        wallet: Wallet,
        networks: BatteryNetworks,
        showsClose: Bool,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> UIViewController {
        let mapper = BatteryChargesMapper(batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation)
        let networks = wallet.batteryTransactionNetworks(relayedChains: networks.relayedChains).map { network in
            BatterySupportedTransactionsView.Network(
                id: network.chain.rawValue,
                title: network.chain.shortDisplayTitle,
                rows: network.transactions.map { transaction in
                    BatterySupportedTransactionsView.Row(
                        id: transaction.rawValue,
                        title: transaction.name,
                        caption: mapper.getChargesCountString(transaction: transaction, chain: network.chain, wallet: wallet)
                    )
                }
            )
        }
        weak var weakController: UIViewController?
        let controller = TKHostingController(content: BatterySupportedTransactionsView(
            networks: networks,
            onBack: { weakController?.navigationController?.popViewController(animated: true) },
            onClose: showsClose ? { weakController?.dismiss(animated: true) } : nil
        ))
        weakController = controller
        return controller
    }
}
