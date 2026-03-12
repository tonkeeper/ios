import Foundation
import KeeperCore
import TonSwift

final class BatteryTokenPickerModel: TokenPickerModel {
    var didUpdateState: ((TokenPickerModelState?) -> Void)?

    private let wallet: Wallet
    private let selectedToken: TonToken
    private let balanceStore: ConvertedBalanceStore
    private let batteryService: BatteryService

    init(
        wallet: Wallet,
        selectedToken: TonToken,
        balanceStore: ConvertedBalanceStore,
        batteryService: BatteryService
    ) {
        self.wallet = wallet
        self.selectedToken = selectedToken
        self.balanceStore = balanceStore
        self.batteryService = batteryService

        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateConvertedBalance(wallet):
                guard wallet == observer.wallet else { return }
                Task {
                    await observer.didUpdateBalanceState()
                }
            }
        }
    }

    func getState() -> TokenPickerModelState? {
        let balanceState = balanceStore.state[wallet]
        return getState(
            balanceState: balanceState,
            rechargeMethods: batteryService.getRechargeMethods(
                wallet: wallet,
                includeRechargeOnly: false
            ),
            scrollToSelected: false
        )
    }
}

private extension BatteryTokenPickerModel {
    func didUpdateBalanceState() async {
        let balanceState = balanceStore.state[wallet]
        let state = getState(
            balanceState: balanceState,
            rechargeMethods: batteryService.getRechargeMethods(
                wallet: wallet,
                includeRechargeOnly: false
            ),
            scrollToSelected: false
        )
        self.didUpdateState?(state)
    }

    func getState(
        balanceState: ConvertedBalanceState?,
        rechargeMethods: [BatteryRechargeMethod],
        scrollToSelected: Bool
    ) -> TokenPickerModelState? {
        guard let balance = balanceState?.balance else { return nil }

        let onlyRechargeMethods = rechargeMethods.filter { $0.supportRecharge }
        let jettonBalances: [ConvertedJettonBalance] = balance.jettonsBalance
            .filter { !$0.jettonBalance.quantity.isZero || $0.jettonBalance.item.jettonInfo.isTonUSDT }
            .filter { jettonBalance in
                onlyRechargeMethods.contains(where: { rechargeMethod in
                    rechargeMethod.jettonMasterAddress == jettonBalance.jettonBalance.item.jettonInfo.address
                })
            }

        return TokenPickerModelState(
            wallet: wallet,
            tonBalance: balance.tonBalance,
            jettonBalances: jettonBalances,
            tronUSDTBalance: nil,
            selectedToken: .ton(selectedToken),
            scrollToSelected: scrollToSelected,
            mode: .balance(showConverted: false)
        )
    }
}
