import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

protocol StakingDepositInputPoolPickerModuleInput: AnyObject {
    func setStakingPool(_ stakingPool: StackingPoolInfo)
    func setInputAmount(_ amount: BigUInt)
}

protocol StakingDepositInputPoolPickerModuleOutput: AnyObject {
    var didTapPicker: ((_ model: StakingListModel) -> Void)? { get set }
}

final class StakingDepositInputPoolPickerViewController: UIViewController, StakingDepositInputPoolPickerModuleInput, StakingDepositInputPoolPickerModuleOutput {
    // MARK: - StakingDepositInputPoolPickerModuleInput

    func setStakingPool(_ stakingPool: StackingPoolInfo) {
        self.stakingPool = stakingPool
    }

    func setInputAmount(_ amount: BigUInt) {
        self.inputAmount = amount
    }

    // MARK: - StakingDepositInputPoolPickerModuleOutput

    var didTapPicker: ((StakingListModel) -> Void)?

    private let listItemButton = TKListItemButton()

    private var stakingPool: StackingPoolInfo? {
        get {
            selectedStakingPool
        }
        set {
            selectedStakingPool = newValue
            reconfigure()
        }
    }

    private var inputAmount: BigUInt = 0 {
        didSet {
            reconfigure()
        }
    }

    private let wallet: Wallet
    private var selectedStakingPool: StackingPoolInfo?
    private let stakingPoolsStore: StakingPoolsStore
    private let processedBalanceStore: ProcessedBalanceStore
    private let amountFormatter: AmountFormatter
    private let configuration: Configuration

    init(
        wallet: Wallet,
        selectedStakingPool: StackingPoolInfo?,
        stakingPoolsStore: StakingPoolsStore,
        processedBalanceStore: ProcessedBalanceStore,
        amountFormatter: AmountFormatter,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.selectedStakingPool = selectedStakingPool
        self.stakingPoolsStore = stakingPoolsStore
        self.processedBalanceStore = processedBalanceStore
        self.amountFormatter = amountFormatter
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(listItemButton)

        listItemButton.isCornerRadius = true
        listItemButton.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        reconfigure()
    }

    private func reconfigure() {
        guard let selectedStakingPool else {
            listItemButton.isHidden = true
            return
        }
        listItemButton.isHidden = false
        let profit: BigUInt = {
            let apy = selectedStakingPool.apy
            let apyFractionLength = max(Int(-apy.exponent), 0)
            let apyPlain = NSDecimalNumber(decimal: apy).multiplying(byPowerOf10: Int16(apyFractionLength))
            let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)

            let scalingFactor = BigUInt(100) * BigUInt(10).power(apyFractionLength)

            return inputAmount * apyBigInt / scalingFactor
        }()
        let isMostProfitable = (stakingPoolsStore.state[wallet] ?? []).profitablePools.contains(where: { $0.address == selectedStakingPool.address })

        let configuration = mapStakingPoolItem(
            selectedStakingPool,
            isMostProfitable: isMostProfitable,
            profit: profit
        )

        self.listItemButton.configuration = TKListItemButton.Configuration(
            listItemConfiguration: configuration,
            accessory: .icon(
                TKListItemIconAccessoryView.Configuration(
                    icon: .TKUIKit.Icons.Size16.switch,
                    tintColor: .Icon.tertiary
                )
            ),
            isEnable: true,
            tapClosure: {
                [weak self] in
                self?.getPickerSections(completion: { model in
                    self?.didTapPicker?(model)
                })
            }
        )
    }
}

private extension StakingDepositInputPoolPickerViewController {
    func mapStakingPoolItem(
        _ item: StackingPoolInfo,
        isMostProfitable: Bool,
        profit: BigUInt
    ) -> TKListItemContentView.Configuration {
        let tagText: String? = isMostProfitable ? .mostProfitableTag : nil
        let percentFormatted = amountFormatter.format(
            decimal: item.apy,
            accessory: .none,
            style: .compact
        )
        var subtitle = "\(String.apy) ≈ \(percentFormatted)%"
        if profit >= BigUInt(stringLiteral: "1000000000") {
            let formatted = amountFormatter.format(
                amount: profit,
                fractionDigits: TonInfo.fractionDigits,
                accessory: .symbol(TonInfo.symbol)
            )
            subtitle += " · \(formatted)"
        }

        let title = item.name

        var tags = [TKTagView.Configuration]()
        if let tagText {
            tags.append(.accentTag(text: tagText, color: .Accent.green))
        }

        return TKListItemContentView.Configuration(
            iconViewConfiguration: TKListItemIconView.Configuration(
                content: .image(
                    TKImageView.Model(
                        image: .image(item.icon),
                        tintColor: .clear,
                        size: .size(CGSize(width: 44, height: 44)),
                        corners: .circle
                    )
                ),
                alignment: .center,
                backgroundColor: .clear,
                size: CGSize(width: 44, height: 44)
            ),
            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                titleViewConfiguration: TKListItemTitleView.Configuration(
                    title: title,
                    tags: tags
                ),
                captionViewsConfigurations: [
                    TKListItemTextView.Configuration(text: subtitle, color: .Text.secondary, textStyle: .body2),
                ]
            )
        )
    }

    func getPickerSections(completion: @escaping (StakingListModel) -> Void) {
        guard let pools = self.stakingPoolsStore.getState()[wallet] else { return }
        let availablePools = pools.filter {
            configuration.value(\.stakingEnabledProviders).contains($0.implementation.type.rawValue)
        }

        let maxAPYPools = Set(availablePools.profitablePools)

        let liquidPools = availablePools.filterByPoolKind(.liquidTF)
            .sorted(by: { $0.apy > $1.apy })
        let whalesPools = availablePools.filterByPoolKind(.whales)
            .sorted(by: { $0.apy > $1.apy })
        let tfPools = availablePools.filterByPoolKind(.tf)
            .sorted(by: { $0.apy > $1.apy })

        var sections = [StakingListSection]()

        if !liquidPools.isEmpty {
            sections.append(
                StakingListSection(
                    title: .liquidStakingTitle,
                    items: liquidPools.enumerated().map { _, pool in
                        .pool(StakingListPool(pool: pool, isMaxAPY: maxAPYPools.contains(pool)))
                    }
                )
            )
        }

        func createGroup(_ pools: [StackingPoolInfo]) -> StakingListItem? {
            guard !pools.isEmpty else { return nil }
            let groupName = pools[0].implementation.name
            let groupImage = pools[0].implementation.icon
            let groupApy = pools[0].apy
            let minAmount = BigUInt(UInt64(pools[0].minStake))
            let isMaxAPY = !maxAPYPools.intersection(Set(pools)).isEmpty
            return StakingListItem.group(
                StakingListGroup(
                    name: groupName,
                    image: groupImage,
                    apy: groupApy,
                    minAmount: minAmount,
                    isMaxAPY: isMaxAPY,
                    items: pools.map { StakingListPool(pool: $0, isMaxAPY: maxAPYPools.contains($0)) }
                )
            )
        }

        if !whalesPools.isEmpty || !tfPools.isEmpty {
            sections.append(
                StakingListSection(
                    title: .otherTitle,
                    items: [whalesPools, tfPools].compactMap { createGroup($0) }
                )
            )
        }

        completion(
            StakingListModel(
                title: TKLocales.StakingDepositPoolPicker.staking,
                sections: sections,
                selectedPool: selectedStakingPool
            )
        )
    }
}

private extension String {
    static let mostProfitableTag = TKLocales.StakingDepositPoolPicker.maxApy
    static let apy = TKLocales.StakingDepositPoolPicker.apy
    static let liquidStakingTitle = TKLocales.StakingDepositPoolPicker.liquidStaking
    static let otherTitle = TKLocales.StakingDepositPoolPicker.other
}
