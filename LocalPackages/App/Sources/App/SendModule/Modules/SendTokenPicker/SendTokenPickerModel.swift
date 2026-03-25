import Foundation
import KeeperCore
import TonSwift

final class SendTokenPickerModel: TokenPickerModel {
    var didUpdateState: ((TokenPickerModelState?) -> Void)?

    enum PickerToken {
        case ton(TonToken)
        case tronUSDT
    }

    private let wallet: Wallet
    private let selectedToken: PickerToken
    private let balanceStore: ConvertedBalanceStore

    init(
        wallet: Wallet,
        selectedToken: PickerToken,
        balanceStore: ConvertedBalanceStore
    ) {
        self.wallet = wallet
        self.selectedToken = selectedToken
        self.balanceStore = balanceStore

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
        return getState(balanceState: balanceState, scrollToSelected: false)
    }
}

private extension SendTokenPickerModel {
    func didUpdateBalanceState() async {
        let balanceState = balanceStore.state[wallet]
        let state = getState(balanceState: balanceState, scrollToSelected: false)
        self.didUpdateState?(state)
    }

    func getState(balanceState: ConvertedBalanceState?, scrollToSelected: Bool) -> TokenPickerModelState? {
        guard let balance = balanceState?.balance else { return nil }

        let selectedToken: TokenPickerModelState.PickerToken = {
            switch self.selectedToken {
            case let .ton(token):
                return .ton(token)
            case .tronUSDT:
                return .tronUSDT
            }
        }()

        return TokenPickerModelState(
            wallet: wallet,
            tonBalance: balance.tonBalance,
            jettonBalances: balance.jettonsBalance.filter { !$0.jettonBalance.quantity.isZero },
            tronUSDTBalance: balance.tronUSDT,
            selectedToken: selectedToken,
            scrollToSelected: scrollToSelected,
            mode: .balance(showConverted: false)
        )
    }
}
