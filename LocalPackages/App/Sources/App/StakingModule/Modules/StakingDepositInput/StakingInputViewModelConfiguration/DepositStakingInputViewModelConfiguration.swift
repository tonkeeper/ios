import BigInt
import Foundation
import KeeperCore
import TKLocalize

final class DepositStakingInputViewModelConfiguration: StakingInputViewModelConfiguration {
    var didUpdateBalance: (() -> Void)?
    var didUpdateMinimumInput: (() -> Void)?

    var title: String {
        TKLocales.Staking.title
    }

    var balance: BigUInt {
        BigUInt(balanceStore.state[wallet]?.balance.tonItem.amount ?? 0)
    }

    var minimumInput: BigUInt? {
        BigUInt(stakingPool?.minStake ?? 0)
    }

    var maxReserve: BigUInt {
        guard let implementation = stakingPool?.implementation else { return 0 }
        return implementation.temporaryReserve + StackingPoolInfo.Implementation.networkFeeMargin
    }

    var maxHint: String? {
        guard let implementation = stakingPool?.implementation else { return nil }
        let reserve = amountFormatter.format(
            amount: implementation.temporaryReserve,
            fractionDigits: TonToken.ton.fractionDigits,
            accessory: .tokenSymbol(TonToken.ton.symbol)
        )
        return TKLocales.StakingInput.maxHint(reserve)
    }

    private var inputAmount: BigUInt = 0

    private let wallet: Wallet
    private var stakingPool: StackingPoolInfo?
    private let balanceStore: ProcessedBalanceStore
    private let amountFormatter: AmountFormatter

    init(
        wallet: Wallet,
        stakingPool: StackingPoolInfo?,
        balanceStore: ProcessedBalanceStore,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.stakingPool = stakingPool
        self.balanceStore = balanceStore
        self.amountFormatter = amountFormatter
    }

    func setStakingPool(_ stakingPool: StackingPoolInfo) {
        self.stakingPool = stakingPool
        didUpdateBalance?()
        didUpdateMinimumInput?()
    }

    func setInputAmount(_ inputAmount: BigUInt) {
        self.inputAmount = inputAmount
    }

    func getStakingConfirmationItem() -> StakingConfirmationItem? {
        guard let stakingPool else { return nil }
        return StakingConfirmationItem(
            operation: .deposit(stakingPool),
            amount: inputAmount
        )
    }
}
