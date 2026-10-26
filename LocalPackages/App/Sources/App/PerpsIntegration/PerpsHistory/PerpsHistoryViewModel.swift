import AppUI
import Combine
import Foundation
import KeeperCore
import PerpsModels
import TKLocalize

@MainActor
final class PerpsHistoryViewModel: ObservableObject {
    let query: MultichainHistoryQueryViewModel
    let title: String
    @Published private(set) var activityToOpen: MultichainActivity?

    private let detailsModelBuilder: MultichainTransactionDetailsModelBuilder
    private let accountStore: (any PerpsAccountStoring)?
    private let withdrawalOperationId: String?
    private let focusedFundingOperationId: String?
    private var focusedTransactions: Set<String>
    private var completedFunding: Set<String> = []
    private var focusedActivity: MultichainActivity?
    private var focusObservation: AnyCancellable?
    private var focusRetryTask: Task<Void, Never>?
    private var withdrawalRefreshTask: Task<Void, Never>?
    private let withdrawalRefreshSleep: @MainActor (UInt64) async throws -> Void
    private var isVisible = false
    private var withdrawalRefreshStep = 0
    private var withdrawalIsListed = false

    init(
        multichainState: MultichainWalletState,
        marketId: Int64?,
        focusedTransactions: Set<String> = [],
        withdrawalOperationId: String? = nil,
        focusedFundingOperationId: String? = nil,
        accountStore: (any PerpsAccountStoring)? = nil,
        multichainService: MultichainService,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        nftResolver: MultichainActivityNFTResolver,
        withdrawalRefreshSleep: @escaping @MainActor (UInt64) async throws -> Void = {
            try await Task.sleep(nanoseconds: $0)
        }
    ) {
        self.title = marketId == nil ? TKLocales.Perps.history : TKLocales.Perps.Asset.transactionHistory
        self.query = MultichainHistoryQueryViewModel(
            multichainState: multichainState,
            category: marketId.map {
                .asset(assetId: PerpsMarketAssetID.make(marketId: $0), typeFilter: .perps)
            } ?? .perps,
            showsPerps: true,
            multichainService: multichainService,
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            nftResolver: nftResolver
        )
        self.detailsModelBuilder = MultichainTransactionDetailsModelBuilder(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            transactionButtonProvider: MultichainTransactionDetailsModelBuilder.transactionButton,
            nftProvider: { [nftResolver] in nftResolver.nft(for: $0) }
        )
        self.accountStore = accountStore
        self.withdrawalOperationId = withdrawalOperationId
        self.focusedFundingOperationId = focusedFundingOperationId
        self.focusedTransactions = focusedTransactions
        self.withdrawalRefreshSleep = withdrawalRefreshSleep
        observeFunding()
        updateFocusedTransactions()
        guard !self.focusedTransactions.isEmpty || focusedFundingOperationId != nil else { return }
        focusObservation = query.$state.sink { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.resolveFocus(self.focusedTransactions, in: state)
            }
        }
    }

    deinit {
        focusRetryTask?.cancel()
        withdrawalRefreshTask?.cancel()
    }

    func screenDidAppear() {
        isVisible = true
        startWithdrawalRefreshIfNeeded()
        publishFocusedActivity()
    }

    func screenWillDisappear() {
        isVisible = false
        withdrawalRefreshTask?.cancel()
        withdrawalRefreshTask = nil
    }

    func didOpenFocusedActivity() {
        activityToOpen = nil
    }

    func transactionDetailsModel(for activity: MultichainActivity) -> MultichainTransactionDetailsModel {
        detailsModelBuilder.build(activity: activity)
    }
}

private extension PerpsHistoryViewModel {
    static let withdrawalRefreshDelays: [UInt64] = [500_000_000, 2_000_000_000, 5_000_000_000]
        + Array(repeating: 10_000_000_000, count: 5)
        + [2_500_000_000]

    func observeFunding() {
        guard let accountStore else { return }
        let activity = accountStore.fundingActivity()
        completedFunding = activity.completed
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.fundingDidChange() }
        }
    }

    /// A pending deposit or withdrawal row turns final only in a fresh page, and its
    /// arrival is the moment the store sees the operation complete.
    func fundingDidChange() {
        guard let activity = accountStore?.fundingActivity() else { return }
        let hashesChanged = updateFocusedTransactions()
        resolveFocus(focusedTransactions, in: query.state)
        let completedWithdrawal = withdrawalOperationId.map { activity.completed.contains($0) } ?? false
        let completed = activity.completed
        let arrived = !completed.isSubset(of: completedFunding)
        completedFunding = completed
        guard arrived || hashesChanged else {
            if completedWithdrawal { stopWithdrawalRefreshIfListed() }
            return
        }
        focusRetryTask?.cancel()
        focusRetryTask = nil
        Task { [weak self] in
            await self?.query.refresh()
            self?.stopWithdrawalRefreshIfListed()
        }
    }

    func startWithdrawalRefreshIfNeeded() {
        guard withdrawalOperationId != nil || focusedFundingOperationId != nil,
              isVisible, withdrawalRefreshTask == nil else { return }
        stopWithdrawalRefreshIfListed()
        let start = withdrawalRefreshStep
        guard !withdrawalIsListed, start < Self.withdrawalRefreshDelays.count else { return }
        withdrawalRefreshTask = Task { [weak self, sleep = withdrawalRefreshSleep] in
            for delay in Self.withdrawalRefreshDelays.dropFirst(start) {
                do {
                    try await sleep(delay)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                self.withdrawalRefreshStep += 1
                await self.query.refresh()
                guard !Task.isCancelled else { return }
                self.stopWithdrawalRefreshIfListed()
            }
            guard !Task.isCancelled else { return }
            self?.withdrawalRefreshTask = nil
        }
    }

    func stopWithdrawalRefreshIfListed() {
        guard let operationId = focusedFundingOperationId ?? withdrawalOperationId else { return }
        let hashes = focusedFundingOperationId != nil ? focusedTransactions : transactions(of: operationId)
        guard !hashes.isEmpty,
              query.state.activities.contains(where: { activity in
                  (focusedFundingOperationId != nil || activity.activityType == .perpsBalanceWithdrawal)
                      && MultichainHistoryEventTarget.activity(
                          transactionHashes: hashes,
                          in: [activity]
                      ) != nil
              })
        else { return }
        withdrawalIsListed = true
        withdrawalRefreshTask?.cancel()
        withdrawalRefreshTask = nil
    }

    func resolveFocus(_ transactions: Set<String>, in state: MultichainHistoryQueryViewModel.State) {
        guard focusObservation != nil else { return }
        guard !transactions.isEmpty else { return }
        guard let activity = MultichainHistoryEventTarget.activity(transactionHashes: transactions, in: state.activities) else {
            if case .loaded = state { retryFocus() }
            return
        }
        focusObservation = nil
        focusRetryTask?.cancel()
        focusRetryTask = nil
        focusedActivity = activity
        publishFocusedActivity()
    }

    func transactions(of operationId: String) -> Set<String> {
        accountStore?.fundingActivity().transactions
            .first { $0.key.caseInsensitiveCompare(operationId) == .orderedSame }?.value ?? []
    }

    @discardableResult
    func updateFocusedTransactions() -> Bool {
        guard let focusedFundingOperationId else { return false }
        let hashes = focusedTransactions.union(transactions(of: focusedFundingOperationId))
        guard hashes != focusedTransactions else { return false }
        focusedTransactions = hashes
        return true
    }

    func retryFocus() {
        guard focusRetryTask == nil else { return }
        focusRetryTask = Task { [weak self] in
            for delay in [1_000_000_000, 2_000_000_000, 4_000_000_000, 8_000_000_000] as [UInt64] {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, let self, self.focusObservation != nil else { return }
                await self.query.refresh()
            }
        }
    }

    func publishFocusedActivity() {
        guard isVisible, let activity = focusedActivity else { return }
        focusedActivity = nil
        activityToOpen = activity
    }
}
