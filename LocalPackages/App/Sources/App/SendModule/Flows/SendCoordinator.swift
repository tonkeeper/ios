import Foundation
import KeeperCore
import TKCoordinator
import TronSwift

@MainActor
protocol SendCoordinator: Coordinator {
    var didFinish: ((RouterCoordinator<NavigationControllerRouter>?) -> Void)? { get set }
    var didSendSuccessfully: ((RouterCoordinator<NavigationControllerRouter>?) -> Void)? { get set }
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)? { get set }
    var didRequestRefill: ((Token, _ onRefill: @escaping () -> Void) -> Void)? { get set }
    var didRequestOpenBattery: ((@escaping () -> Void) -> Void)? { get set }
    var didRequestFeeDeposit: ((_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void)? { get set }

    func start(pushAnimated: Bool)
    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool
}

extension SendCoordinator {
    func handleFeeRefillRequest(
        extraType: TransactionConfirmationModel.ExtraType,
        onRefresh: @escaping () -> Void
    ) {
        if case .battery = extraType {
            didRequestOpenBattery?(onRefresh)
            return
        }

        if case .default = extraType {
            didRequestRefill?(.ton(.ton), onRefresh)
            return
        }

        if case let .gasless(token) = extraType {
            switch token.symbol?.uppercased() {
            case TRX.symbol.uppercased():
                didRequestRefill?(.tron(.trx), onRefresh)
            default:
                didRequestRefill?(.ton(.jetton(JettonItem(jettonInfo: token, walletAddress: token.address))), onRefresh)
            }
        }
    }
}
