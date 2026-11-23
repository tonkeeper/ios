import AppUI
import BigInt
import Foundation
import KeeperCore
import TKLocalize

@MainActor
final class StakingRewardsHistoryViewModel: ObservableObject {
    @Published private(set) var state: StakingRewardsHistoryState

    var didTapBack: (() -> Void)?

    private static let pageSize = 50
    private static let periods: [(StakingRewardsPeriod, String)] = [
        (.allTime, TKLocales.StakingBalanceDetails.periodAllTime),
        (.month, TKLocales.StakingBalanceDetails.period1Month),
        (.halfYear, TKLocales.StakingBalanceDetails.period6Months),
        (.year, TKLocales.StakingBalanceDetails.period1Year),
    ]

    private var selectedPeriodIndex = 0
    private var rewards: [StakingReward] = []
    private var rewardIds: Set<String> = []
    /// Server items consumed so far; rewards without an amount are dropped, so it can exceed `rewards.count`.
    private var serverOffset = 0
    private var total: BigUInt?
    private var totalCount = 0
    private var loadTask: Task<Void, Never>?

    private let address: String?
    private let stakingRewardsService: StakingRewardsService
    private let rewardRowMapper: StakingRewardRowMapper
    private let amountFormatter: AmountFormatter
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore

    init(
        wallet: Wallet,
        stakingRewardsService: StakingRewardsService,
        rewardRowMapper: StakingRewardRowMapper,
        amountFormatter: AmountFormatter,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore
    ) {
        self.address = try? wallet.address.toRaw()
        self.stakingRewardsService = stakingRewardsService
        self.rewardRowMapper = rewardRowMapper
        self.amountFormatter = amountFormatter
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.state = StakingRewardsHistoryState(
            total: nil,
            periods: Self.periods.map(\.1),
            selectedPeriodIndex: 0,
            content: .loading
        )
    }

    func viewDidLoad() {
        reload()
    }

    func selectPeriod(index: Int) {
        guard index != selectedPeriodIndex, Self.periods.indices.contains(index) else { return }
        selectedPeriodIndex = index
        reload()
    }

    func refresh() async {
        reload()
        await loadTask?.value
    }

    func retry() {
        guard loadTask == nil else { return }
        if rewards.isEmpty {
            reload()
        } else {
            loadPage(offset: serverOffset)
        }
    }

    func loadNextPageIfNeeded(row: StakingRewardRowState) {
        guard loadTask == nil,
              serverOffset < totalCount,
              rewards.last?.id == row.id
        else { return }
        loadPage(offset: serverOffset)
    }
}

private extension StakingRewardsHistoryViewModel {
    enum Content {
        case loading
        case rows(isLoadingMore: Bool, isLoadMoreFailed: Bool = false)
        case failed
    }

    func reload() {
        loadTask?.cancel()
        loadTask = nil
        rewards = []
        rewardIds = []
        serverOffset = 0
        total = nil
        totalCount = 0
        updateState(content: .loading)
        loadPage(offset: 0)
    }

    func loadPage(offset: Int) {
        guard let address else {
            updateState(content: .failed)
            return
        }
        let period = Self.periods[selectedPeriodIndex].0
        if offset > 0 {
            updateState(content: .rows(isLoadingMore: true))
        }
        loadTask = Task { [weak self, stakingRewardsService] in
            let page = try? await stakingRewardsService.loadRewards(
                address: address,
                period: period,
                limit: Self.pageSize,
                offset: offset
            )
            guard let self, !Task.isCancelled else { return }
            self.loadTask = nil
            guard let page else {
                self.updateState(
                    content: self.rewards.isEmpty ? .failed : .rows(isLoadingMore: false, isLoadMoreFailed: true)
                )
                return
            }
            if offset == 0 {
                self.total = page.total ?? 0
            }
            let countBefore = self.rewards.count
            for reward in page.items where self.rewardIds.insert(reward.id).inserted {
                self.rewards.append(reward)
            }
            self.serverOffset = offset + page.serverItemsCount
            self.totalCount = page.totalCount
            // A page that adds no row leaves no new last row whose appearance would request the next one.
            if self.rewards.count == countBefore, page.serverItemsCount > 0, self.serverOffset < self.totalCount {
                self.loadPage(offset: self.serverOffset)
                return
            }
            self.updateState(content: .rows(isLoadingMore: false))
        }
    }

    func updateState(content: Content) {
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let stateContent: StakingRewardsHistoryState.Content
        switch content {
        case .loading:
            stateContent = .loading
        case .failed:
            stateContent = .failed
        case let .rows(isLoadingMore, isLoadMoreFailed):
            stateContent = .rows(
                rewards.map { rewardRowMapper.map(reward: $0, isSecureMode: isSecureMode) },
                isLoadingMore: isLoadingMore,
                isLoadMoreFailed: isLoadMoreFailed
            )
        }
        state = StakingRewardsHistoryState(
            total: total.map { buildTotal(amount: $0, isSecureMode: isSecureMode) },
            periods: state.periods,
            selectedPeriodIndex: selectedPeriodIndex,
            content: stateContent
        )
    }

    func buildTotal(amount: BigUInt, isSecureMode: Bool) -> StakingRewardsHistoryState.Total {
        guard !isSecureMode else {
            return .init(amount: .secureModeValueShort, fiat: .secureModeValueShort)
        }
        let currency = currencyStore.getState()
        let fiat = tonRatesStore.getState().tonRates.first(where: { $0.currency == currency }).map {
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
        return .init(amount: rewardRowMapper.formatAmount(amount), fiat: fiat)
    }
}
