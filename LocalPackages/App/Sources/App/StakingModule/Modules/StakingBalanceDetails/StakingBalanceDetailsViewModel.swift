import AppUI
import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol StakingBalanceDetailsModuleOutput: AnyObject {
    var didOpenURL: ((URL) -> Void)? { get set }
    var didOpenURLInApp: ((URL, String?) -> Void)? { get set }
    var openJettonDetails: ((_ wallet: Wallet, _ jettonItem: JettonItem) -> Void)? { get set }
    var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
    var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
    var didTapCollect: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }
    var didTapRewardsHistory: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
}

protocol StakingBalanceDetailsViewModel: AnyObject {
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
    var didUpdateRewardsViewModel: ((StakingBalanceDetailsRewardsView.Model?) -> Void)? { get set }
    var didUpdateRewardsHistory: ((StakingRewardsHistorySectionState?) -> Void)? { get set }
    var didUpdateUpcomingReward: ((StakingUpcomingRewardSectionState?) -> Void)? { get set }
    var didUpdateDetailsTitle: ((TKListTitleView.Model) -> Void)? { get set }
    var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)? { get set }
    var didUpdateDescription: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)? { get set }
    var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)? { get set }
    var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateStakeStateView: ((TKListItemButton.Configuration?) -> Void)? { get set }
    var didUpdateButtonsView: ((StakingBalanceDetailsActionBarView.Model) -> Void)? { get set }

    func viewDidLoad()
    func didTapRewardsHistoryButton()
}

final class StakingBalanceDetailsViewModelImplementation: StakingBalanceDetailsViewModel, StakingBalanceDetailsModuleOutput {
    // MARK: - StakingBalanceDetailsModuleOutput

    var didOpenURL: ((URL) -> Void)?
    var didOpenURLInApp: ((URL, String?) -> Void)?
    var openJettonDetails: ((Wallet, JettonItem) -> Void)?
    var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
    var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
    var didTapCollect: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didTapRewardsHistory: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?

    // MARK: - StakingViewModel

    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
    var didUpdateRewardsViewModel: ((StakingBalanceDetailsRewardsView.Model?) -> Void)?
    var didUpdateRewardsHistory: ((StakingRewardsHistorySectionState?) -> Void)?
    var didUpdateUpcomingReward: ((StakingUpcomingRewardSectionState?) -> Void)?
    var didUpdateDetailsTitle: ((TKListTitleView.Model) -> Void)?
    var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)?
    var didUpdateDescription: ((NSAttributedString?) -> Void)?
    var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)?
    var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)?
    var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)?
    var didUpdateStakeStateView: ((TKListItemButton.Configuration?) -> Void)?
    var didUpdateButtonsView: ((StakingBalanceDetailsActionBarView.Model) -> Void)?

    // MARK: - State

    private let queue = DispatchQueue(label: "StakingBalanceDetailsViewModelImplementationQueue")
    private var balanceItem: ProcessedBalanceStakingItem?
    private var jettonBalanceItem: ProcessedBalanceJettonItem?

    // MARK: - Dependencies

    private let wallet: Wallet
    private let stakingPoolInfo: StackingPoolInfo
    private let listViewModelBuilder: StakingListViewModelBuilder
    private let linksViewModelBuilder: StakingLinksViewModelBuilder
    private let balanceItemMapper: BalanceItemMapper
    private let stakingPoolsStore: StakingPoolsStore
    private let balanceStore: ProcessedBalanceStore
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let amountFormatter: AmountFormatter
    private let configuration: Configuration
    private let stakingRewardsService: StakingRewardsService
    private let rewardRowMapper: StakingRewardRowMapper

    // MARK: - Init

    init(
        wallet: Wallet,
        stakingPoolInfo: StackingPoolInfo,
        listViewModelBuilder: StakingListViewModelBuilder,
        linksViewModelBuilder: StakingLinksViewModelBuilder,
        balanceItemMapper: BalanceItemMapper,
        stakingPoolsStore: StakingPoolsStore,
        balanceStore: ProcessedBalanceStore,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        amountFormatter: AmountFormatter,
        configuration: Configuration,
        stakingRewardsService: StakingRewardsService,
        rewardRowMapper: StakingRewardRowMapper
    ) {
        self.wallet = wallet
        self.stakingPoolInfo = stakingPoolInfo
        self.listViewModelBuilder = listViewModelBuilder
        self.linksViewModelBuilder = linksViewModelBuilder
        self.balanceItemMapper = balanceItemMapper
        self.stakingPoolsStore = stakingPoolsStore
        self.balanceStore = balanceStore
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.amountFormatter = amountFormatter
        self.configuration = configuration
        self.stakingRewardsService = stakingRewardsService
        self.rewardRowMapper = rewardRowMapper
    }

    func viewDidLoad() {
        didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: stakingPoolInfo.name))
        queue.sync {
            prepareInitialState()
            updateInformation()
            updateDescription()
            updateDetailsTitle()
            updateList()
            updateLinks()
            updateJettonItemView()
            updateStakeStateView()
            updateButtons()
        }
        updateRewardBlocks()
    }

    func didTapRewardsHistoryButton() {
        didTapRewardsHistory?(wallet, stakingPoolInfo)
    }
}

private extension StakingBalanceDetailsViewModelImplementation {
    func buildRewardsModel(rewards: StakingCurrentRewards) -> StakingBalanceDetailsRewardsView.Model? {
        guard rewards.monthly > 0, rewards.yearly > 0 else { return nil }

        let isSecureMode = appSettingsStore.getState().isSecureMode
        let currency = currencyStore.getState()
        let rate = tonRatesStore.getState().tonRates.first(where: { $0.currency == currency })

        func card(title: String, amount: BigUInt) -> StakingBalanceDetailsRewardsView.Model.Card {
            guard !isSecureMode else {
                return .init(title: title, value: .secureModeValueShort, fiatValue: .secureModeValueShort)
            }
            let fiatValue = rate.map {
                amountFormatter.format(
                    decimal: RateConverter().convertToDecimal(
                        amount: amount,
                        amountFractionLength: TonInfo.fractionDigits,
                        rate: $0
                    ),
                    accessory: .fiat(currency),
                    style: .fiatBalance
                )
            } ?? ""
            return .init(title: title, value: rewardRowMapper.formatAmount(amount), fiatValue: fiatValue)
        }

        return StakingBalanceDetailsRewardsView.Model(
            title: TKLocales.StakingBalanceDetails.currentRewards,
            cards: [
                card(title: TKLocales.StakingBalanceDetails.monthly, amount: rewards.monthly),
                card(title: TKLocales.StakingBalanceDetails.yearly, amount: rewards.yearly),
            ]
        )
    }

    func updateRewardBlocks() {
        guard stakingPoolInfo.implementation.type == .liquidTF,
              wallet.network == .mainnet,
              let address = try? wallet.address.toRaw()
        else {
            didUpdateUpcomingReward?(nil)
            didUpdateRewardsHistory?(nil)
            didUpdateRewardsViewModel?(nil)
            return
        }

        Task { @MainActor [weak self, stakingRewardsService, stakingPoolInfo] in
            async let page = try? stakingRewardsService.loadRewards(
                address: address,
                period: .allTime,
                limit: 3,
                offset: 0
            )
            async let forecast = try? stakingRewardsService.loadRewardsForecast(
                address: address,
                apy: stakingPoolInfo.apy
            )
            let (loadedPage, loadedForecast) = await(page, forecast)
            guard let self else { return }
            let isSecureMode = self.appSettingsStore.getState().isSecureMode
            self.didUpdateUpcomingReward?(loadedForecast?.upcoming.map {
                self.rewardRowMapper.mapUpcoming(
                    reward: $0,
                    // Unknown when the history failed to load; "Current round" is right for anyone already paid.
                    isFirstReward: loadedPage?.items.isEmpty ?? false,
                    isSecureMode: isSecureMode
                )
            })
            self.didUpdateRewardsHistory?(loadedPage.flatMap { self.buildRewardsHistory(page: $0) })
            self.didUpdateRewardsViewModel?(loadedForecast?.current.flatMap { self.buildRewardsModel(rewards: $0) })
        }
    }

    func buildRewardsHistory(page: StakingRewardsPage) -> StakingRewardsHistorySectionState? {
        guard !page.items.isEmpty else { return nil }
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let total = isSecureMode ? .secureModeValueShort : rewardRowMapper.formatAmount(page.total ?? 0)
        return StakingRewardsHistorySectionState(
            total: total,
            rows: page.items.map { rewardRowMapper.map(reward: $0, isSecureMode: isSecureMode) }
        )
    }

    func updateDetailsTitle() {
        let model = TKListTitleView.Model(title: TKLocales.StakingBalanceDetails.details, textStyle: .h3)
        DispatchQueue.main.async {
            self.didUpdateDetailsTitle?(model)
        }
    }

    func updateList() {
        let profitablePools = stakingPoolsStore.getState()[wallet]?.profitablePools
        let model = self.listViewModelBuilder.build(
            stakingPoolInfo: stakingPoolInfo,
            isMaxAPY: profitablePools?.contains(where: { $0.address == self.stakingPoolInfo.address }) == true
        )
        DispatchQueue.main.async {
            self.didUpdateListViewModel?(model)
        }
    }

    func updateLinks() {
        let model = linksViewModelBuilder.buildModel(
            poolInfo: stakingPoolInfo,
            openURL: { [weak self] url in
                self?.didOpenURL?(url)
            },
            openURLInApp: { [weak self] url in
                self?.didOpenURLInApp?(url, nil)
            }
        )
        DispatchQueue.main.async {
            self.didUpdateLinksViewModel?(model)
        }
    }

    func updateDescription() {
        didUpdateDescription?(
            String.description.withTextStyle(
                .body3,
                color: .Text.tertiary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )
        )
    }

    func prepareInitialState() {
        guard let balance = balanceStore.getState()[wallet]?.balance else {
            return
        }

        self.balanceItem = balance.stakingItems.first(where: { $0.poolInfo?.address == stakingPoolInfo.address })
        self.jettonBalanceItem = balanceItem?.jetton
    }

    var stakeAmount: BigUInt {
        BigUInt(UInt64(max(balanceItem?.info.amount ?? 0, 0)))
    }

    var isDustStake: Bool {
        isStakeDust(amount: stakeAmount, fractionDigits: TonInfo.fractionDigits)
    }

    func updateInformation() {
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let isDust = isDustStake

        let tokenAmount: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    amount: isDust ? 0 : stakeAmount,
                    fractionDigits: TonInfo.fractionDigits,
                    accessory: .tokenSymbol(TonInfo.symbol),
                    style: .exactValue
                )
            }
        }()

        let convertedAmount: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    decimal: isDust ? 0 : balanceItem?.amountConverted ?? 0,
                    accessory: .fiat(balanceItem?.currency ?? currencyStore.getState()),
                    style: .fiatBalance
                )
            }
        }()

        let imageConfiguration = TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: .image(.TKUIKit.Icons.Size44.currencyTon),
                    size: .size(CGSize(width: 64, height: 64)),
                    corners: .circle
                )
            ),
            alignment: .center,
            size: CGSize(width: 64, height: 64),
            badge: TKListItemIconView.Configuration.Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(stakingPoolInfo.icon)),
                    size: .large
                ),
                position: .bottomRight
            )
        )

        let model = TokenDetailsInformationView.Model(
            imageConfiguration: imageConfiguration,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount
        )

        DispatchQueue.main.async {
            self.didUpdateInformationView?(model)
        }
    }

    func updateJettonItemView() {
        guard let jettonBalanceItem else {
            didUpdateJettonItemView?(nil)
            return
        }

        let isSecureMode = appSettingsStore.getState().isSecureMode

        let configuration = balanceItemMapper.mapJettonItem(
            jettonBalanceItem,
            isSecure: isSecureMode,
            isNetworkBadgeVisible: false
        )
        didUpdateJettonItemView?(
            TKListItemButton.Configuration(
                listItemConfiguration: configuration,
                isEnable: true,
                tapClosure: { [weak self] in
                    guard let self else { return }
                    self.openJettonDetails?(self.wallet, jettonBalanceItem.jetton)
                }
            )
        )

        didUpdateJettonButtonDescription?(
            String.jettonButtonDescription.withTextStyle(
                .body3,
                color: .Text.tertiary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )
        )
    }

    func updateStakeStateView() {
        guard let balanceItem else {
            didUpdateStakeStateView?(nil)
            return
        }

        let isSecureMode = appSettingsStore.getState().isSecureMode
        let currency = currencyStore.getState()

        func convert(amount: Int64) -> Decimal {
            let converter = RateConverter()

            if let rate = tonRatesStore.getState().tonRates.first(where: { $0.currency == currency }) {
                return converter.convertToDecimal(
                    amount: BigUInt(UInt64(amount)),
                    amountFractionLength: TonInfo.fractionDigits,
                    rate: rate
                )
            }
            return 0
        }

        let title: String
        let subtitle: String
        let amount: Int64
        let converted: Decimal
        let tapClosure: (() -> Void)?

        if balanceItem.info.pendingDeposit > 0 {
            amount = balanceItem.info.pendingDeposit
            converted = convert(amount: balanceItem.info.pendingDeposit)
            title = .pendingStakeTitle
            subtitle = .afterTheEndOfTheCycle
            tapClosure = nil
        } else if balanceItem.info.pendingWithdraw > 0 {
            amount = balanceItem.info.pendingWithdraw
            converted = convert(amount: balanceItem.info.pendingWithdraw)
            title = .pendingUntakeTitle
            subtitle = .afterTheEndOfTheCycle
            tapClosure = nil
        } else if balanceItem.info.readyWithdraw > 0 {
            amount = balanceItem.info.readyWithdraw
            converted = convert(amount: balanceItem.info.readyWithdraw)
            title = .unstakeReadyTitle
            subtitle = .tapToCollect
            tapClosure = { [weak self, wallet] in
                guard let poolInfo = balanceItem.poolInfo else { return }
                self?.didTapCollect?(wallet, poolInfo, balanceItem.info)
            }
        } else {
            didUpdateStakeStateView?(nil)
            return
        }

        let amountFormatted: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    amount: BigUInt(UInt64(amount)),
                    fractionDigits: TonInfo.fractionDigits,
                    accessory: .tokenSymbol(TonInfo.symbol)
                )
            }
        }()

        let convertedFormatted: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    decimal: converted,
                    accessory: .fiat(currency),
                    style: .fiatBalance
                )
            }
        }()

        let configuration = TKListItemButton.Configuration(
            listItemConfiguration: TKListItemContentView.Configuration(
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
                    captionViewsConfigurations: [TKListItemTextView.Configuration(
                        text: subtitle,
                        color: .Text.secondary,
                        textStyle: .body2
                    )],
                    valueViewConfiguration: TKListItemTextView.Configuration(
                        text: amountFormatted,
                        color: .Text.primary,
                        textStyle: .label1
                    ),
                    valueCaptionViewConfiguration: TKListItemTextView.Configuration(
                        text: convertedFormatted,
                        color: .Text.secondary,
                        textStyle: .body2
                    )
                )
            ),
            isEnable: wallet.isStakeEnable,
            tapClosure: tapClosure
        )

        didUpdateStakeStateView?(configuration)
    }

    func updateButtons() {
        let model = StakingBalanceDetailsActionBarView.Model(
            buttons: [
                StakingBalanceDetailsActionBarView.Model.Button(
                    title: .stakeTitle,
                    isEnabled: !configuration.flag(\.stakingDisabled, network: wallet.network)
                        && configuration.value(\.stakingEnabledProviders)
                        .contains(stakingPoolInfo.implementation.type.rawValue)
                        && wallet.isStakeEnable,
                    action: { [weak self, wallet, stakingPoolInfo] in
                        self?.didTapStake?(wallet, stakingPoolInfo)
                    },
                    accessibilityIdentifier: "staking_balance_stake"
                ),
                StakingBalanceDetailsActionBarView.Model.Button(
                    title: .unstakeTitle,
                    isEnabled: wallet.isStakeEnable && !isDustStake,
                    action: { [weak self, wallet, stakingPoolInfo] in
                        self?.didTapUnstake?(wallet, stakingPoolInfo)
                    },
                    accessibilityIdentifier: "staking_balance_unstake"
                ),
            ]
        )
        didUpdateButtonsView?(model)
    }
}

private extension String {
    static let description = TKLocales.StakingBalanceDetails.description
    static let jettonButtonDescription = TKLocales.StakingBalanceDetails.jettonButtonDescription
    static let pendingStakeTitle = TKLocales.StakingBalanceDetails.pendingStake
    static let pendingUntakeTitle = TKLocales.StakingBalanceDetails.pendingUnstake
    static let unstakeReadyTitle = TKLocales.StakingBalanceDetails.unstakeReady
    static let afterTheEndOfTheCycle = TKLocales.StakingBalanceDetails.afterEndOfCycle
    static let tapToCollect = TKLocales.StakingBalanceDetails.tapToCollect
    static let stakeTitle = TKLocales.StakingBalanceDetails.stake
    static let unstakeTitle = TKLocales.StakingBalanceDetails.unstake
}
