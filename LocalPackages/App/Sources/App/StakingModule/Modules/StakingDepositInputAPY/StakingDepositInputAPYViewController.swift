import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

protocol StakingDepositInputAPYModuleInput: AnyObject {
    func setInputAmount(_ amount: BigUInt)
}

final class StakingDepositInputAPYViewController: UIViewController, StakingDepositInputAPYModuleInput {
    func setInputAmount(_ amount: BigUInt) {
        self.inputAmount = amount
    }

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
    private let balanceStore: ProcessedBalanceStore
    private let amountFormatter: AmountFormatter

    init(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        balanceStore: ProcessedBalanceStore,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.stakingPool = stakingPool
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

        setupBalanceObservation()
        reconfigure()
    }
}

private extension StakingDepositInputAPYViewController {
    func setupBalanceObservation() {
        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateProccessedBalance(wallet):
                guard wallet == observer.wallet else { return }
                DispatchQueue.main.async {
                    observer.reconfigure()
                }
            }
        }
    }

    func reconfigure() {
        let listModel = StakingDetailsListView.Model(
            items: [
                item(
                    title: TKLocales.StakingDepositInput.afterStake,
                    profit: stakingPool.annualProfit(for: inputAmount + stakedAmount)
                ),
                item(
                    title: TKLocales.StakingDepositInput.current,
                    profit: stakingPool.annualProfit(for: stakedAmount)
                ),
            ]
        )

        headerView.configure(
            model: TKListTitleView.Model(
                title: TKLocales.StakingDepositInput.yourApy,
                textStyle: .label1
            )
        )
        listView.configure(model: listModel)
    }

    var stakedAmount: BigUInt {
        BigUInt(
            balanceStore.state[wallet]?.balance.stakingItems
                .first(where: { $0.info.pool == stakingPool.address })?
                .info.amount ?? 0
        )
    }

    func item(title: String, profit: BigUInt) -> StakingDetailsListView.ItemView.Model {
        let formatted = amountFormatter.format(
            amount: profit,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .tokenSymbol(TonInfo.symbol),
            isNegative: false,
            style: .compact
        )
        return StakingDetailsListView.ItemView.Model(
            title: title.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            ),
            tag: nil,
            value: "≈ \(formatted)".withTextStyle(
                .body2,
                color: .Text.primary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        )
    }
}
