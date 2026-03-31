import BigInt
import KeeperCore
import TKUIKit
import UIKit

protocol StakingDepositInputAPYModuleInput: AnyObject {
    func setInputAmount(_ amount: BigUInt)
}

final class StakingDepositInputAPYViewController: UIViewController, StakingDepositInputAPYModuleInput {
    func setInputAmount(_ amount: BigUInt) {
        self.inputAmount = amount
    }

    private var balanceItem: BalanceStakingItemModel?

    private let stackView = UIStackView()
    private let headerView = TKListTitleView()
    private let listView = StakingDetailsListView()

    private var inputAmount: BigUInt = 0 {
        didSet {
            reconfigure()
        }
    }

    private let wallet: Wallet
    private let stakingPool: StackingPoolInfo
    private let stakingPoolsStore: StakingPoolsStore
    private let balanceStore: ConvertedBalanceStore
    private let amountFormatter: AmountFormatter

    init(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        stakingPoolsStore: StakingPoolsStore,
        balanceStore: ConvertedBalanceStore,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.stakingPool = stakingPool
        self.stakingPoolsStore = stakingPoolsStore
        self.balanceStore = balanceStore
        self.amountFormatter = amountFormatter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView.axis = .vertical

        view.addSubview(stackView)
        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(listView)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        headerView.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        reconfigure()
    }

    func reconfigure() {
        func calculateAPY(amount: BigUInt, apy: Decimal) -> (BigUInt, Int) {
            let apyFractionLength = max(Int16(-apy.exponent), 0)
            let apyPlain = NSDecimalNumber(decimal: apy)
                .multiplying(byPowerOf10: apyFractionLength)
            let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)

            let fractionLength = Int(apyFractionLength) + TonInfo.fractionDigits
            let result = amount / 100 * apyBigInt
            return (result, fractionLength)
        }

        guard let balance = balanceStore.getState()[wallet]?.balance else {
            return
        }

        guard let balanceItem = createBalanceItem(balance: balance) else {
            return
        }

        let afterStakeAPY = calculateAPY(amount: inputAmount + BigUInt(UInt64(balanceItem.info.amount)), apy: stakingPool.apy)
        let afterStakeAPYFormatted = amountFormatter.format(
            amount: afterStakeAPY.0,
            fractionDigits: afterStakeAPY.1,
            accessory: .symbol(TonInfo.symbol),
            isNegative: false,
            style: .compact
        )

        let currentAPY = calculateAPY(amount: BigUInt(UInt64(balanceItem.info.amount)), apy: stakingPool.apy)
        let currentAPYFormatted = amountFormatter.format(
            amount: currentAPY.0,
            fractionDigits: currentAPY.1,
            accessory: .symbol(TonInfo.symbol),
            isNegative: false,
            style: .compact
        )

        let listModel = StakingDetailsListView.Model(
            items: [
                StakingDetailsListView.ItemView.Model(
                    title: "After stake".withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    tag: nil,
                    value: "≈ \(afterStakeAPYFormatted)".withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
                ),
                StakingDetailsListView.ItemView.Model(
                    title: "Current".withTextStyle(
                        .body2,
                        color: .Text.secondary,
                        alignment: .left,
                        lineBreakMode: .byTruncatingTail
                    ),
                    tag: nil,
                    value: "≈ \(currentAPYFormatted)".withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
                ),
            ]
        )

        self.headerView.configure(model: TKListTitleView.Model(title: "Your APY", textStyle: .label1))
        self.listView.configure(model: listModel)
    }
}

private extension StakingDepositInputAPYViewController {
    func createBalanceItem(balance: ConvertedBalance) -> BalanceStakingItemModel? {
        if let stakingPoolJetton = balance.jettonsBalance
            .first(where: { $0.jettonBalance.item.jettonInfo.address == stakingPool.liquidJettonMaster })
        {
            var amount: Int64 = 0
            if let tonRate = stakingPoolJetton.jettonBalance.rates[.TON] {
                let converted = RateConverter().convertToDecimal(
                    amount: stakingPoolJetton.jettonBalance.quantity,
                    amountFractionLength: stakingPoolJetton.jettonBalance.item.jettonInfo.fractionDigits,
                    rate: tonRate
                )
                let convertedFractionLength = min(Int16(TonInfo.fractionDigits), max(Int16(-converted.exponent), 0))
                amount = Int64(
                    NSDecimalNumber(decimal: converted)
                        .multiplying(byPowerOf10: convertedFractionLength).doubleValue
                )
            }

            let info = AccountStackingInfo(
                pool: stakingPool.address,
                amount: amount,
                pendingDeposit: 0,
                pendingWithdraw: 0,
                readyWithdraw: 0
            )

            return BalanceStakingItemModel(
                id: info.pool.toRaw(),
                info: info,
                poolInfo: stakingPool,
                currency: balance.currency,
                converted: stakingPoolJetton.converted,
                price: stakingPoolJetton.price
            )
        }

        if let stakingItem = balance.stackingBalance.first(where: { $0.stackingInfo.pool == stakingPool.address }) {
            return BalanceStakingItemModel(
                id: stakingItem.stackingInfo.pool.toRaw(),
                info: stakingItem.stackingInfo,
                poolInfo: stakingPool,
                currency: balance.currency,
                converted: stakingItem.amountConverted,
                price: stakingItem.price
            )
        }

        return nil
    }
}
