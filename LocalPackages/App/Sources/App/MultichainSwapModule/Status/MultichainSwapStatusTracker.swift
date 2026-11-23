import BigInt
import Combine
import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

struct MultichainSwapSentSwap {
    let id = UUID()
    let multichainState: MultichainWalletState
    /// Nil when a relayer broadcast the swap and named no transaction.
    let txHash: String?
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
    let sendAmount: BigUInt
    let estimatedReceiveAmount: BigUInt
    let date: Date
}

struct MultichainSwapTrackedSwap {
    enum Status {
        case pending
        case done
        case failed
    }

    let swap: MultichainSwapSentSwap
    var activity: MultichainActivity?

    var status: Status {
        switch activity?.status {
        case .confirmed: .done
        case .failed, .dropped: .failed
        case .pending, nil: .pending
        }
    }

    var transactionIds: Set<String> {
        var ids = Set(activity.map { activity in
            activity.txIds.map { MultichainTransactionID.normalized($0, chain: activity.fromChain ?? activity.toChain) }
        } ?? [])
        if let txHash = swap.txHash {
            ids.insert(MultichainTransactionID.normalized(txHash, chain: swap.sendAsset.asset.chain))
        }
        return ids
    }
}

/// Follows the last swap sent from the app through the wallet's history and keeps a toast pinned
/// with its progress while the app is in front.
@MainActor
final class MultichainSwapStatusTracker: ObservableObject {
    /// A swap that never lands leaves nothing in history to settle it by.
    private static let unseenLimit: TimeInterval = 10 * 60
    private static let pendingLimit: TimeInterval = 60 * 60
    private static let pollIntervals: [TimeInterval] = [5, 10, 20, 30]
    /// History invalidations come in bursts; one refresh answers them all.
    private static let invalidationDelay: TimeInterval = 0.5
    private static let outcomeToastDuration: TimeInterval = 5

    @Published private(set) var trackedSwap: MultichainSwapTrackedSwap?
    var onOpenDetails: (() -> Void)?

    private let loadActivities: (MultichainWalletState) async throws -> [MultichainActivity]
    private let amountFormatter: AmountFormatter
    private let now: () -> Date
    private let pinToastConfiguration: (ToastPresenter.Configuration) -> Void
    private let unpinToast: () -> Void
    private var refreshTask: Task<Void, Never>?
    private var isForeground = true
    private var isShowingDetails = false
    /// The pending swap's toast was swiped away: only the swap's outcome brings a toast back.
    private var isPendingToastSwipedAway = false
    private var earlierSwapsTransactionIds = Set<String>()

    init(
        loadActivities: @escaping (MultichainWalletState) async throws -> [MultichainActivity],
        amountFormatter: AmountFormatter,
        now: @escaping () -> Date = Date.init,
        pinToast: @escaping (ToastPresenter.Configuration) -> Void = { ToastPresenter.pinToast(configuration: $0) },
        unpinToast: @escaping () -> Void = { ToastPresenter.unpinToast() }
    ) {
        self.loadActivities = loadActivities
        self.amountFormatter = amountFormatter
        self.now = now
        pinToastConfiguration = pinToast
        self.unpinToast = unpinToast
    }

    deinit {
        refreshTask?.cancel()
        unpinToast()
    }

    func track(_ swap: MultichainSwapSentSwap) {
        if let activity = trackedSwap?.activity {
            earlierSwapsTransactionIds.formUnion(activity.txIds)
        }
        trackedSwap = MultichainSwapTrackedSwap(swap: swap)
        isPendingToastSwipedAway = false
        pinToast()
        startRefreshing(after: Self.pollIntervals[0])
    }

    func setForeground(_ isForeground: Bool) {
        self.isForeground = isForeground
        if isForeground {
            startRefreshing(after: 0)
        } else {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    func historyDidChange(multichainWalletId: String) {
        guard trackedSwap?.swap.multichainState.walletId == multichainWalletId else { return }
        startRefreshing(after: Self.invalidationDelay)
    }

    /// The details show the progress themselves, so no toast goes over them.
    func detailsDidOpen() {
        isShowingDetails = true
        unpinToast()
    }

    /// Also runs when a screen covers the details, such as a transaction opened in the browser.
    func detailsDidClose() {
        isShowingDetails = false
        guard trackedSwap?.status == .pending, !isPendingToastSwipedAway else { return }
        pinToast()
    }
}

private extension MultichainSwapStatusTracker {
    func startRefreshing(after delay: TimeInterval) {
        refreshTask?.cancel()
        refreshTask = nil
        guard isForeground, let trackedSwap, trackedSwap.status == .pending else { return }
        let swapId = trackedSwap.swap.id
        refreshTask = Task { [weak self] in
            var delay = delay
            var attempt = 0
            while true {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
                guard let self, await refresh(swapId: swapId) else { return }
                attempt += 1
                delay = Self.pollIntervals[min(attempt, Self.pollIntervals.count - 1)]
            }
        }
    }

    /// - Returns: Whether the swap is still to be followed.
    func refresh(swapId: UUID) async -> Bool {
        guard let swap = trackedSwap?.swap, swap.id == swapId else { return false }
        var activity: MultichainActivity?
        do {
            let activities = try await loadActivities(swap.multichainState)
            activity = swap.activity(in: activities, excluding: earlierSwapsTransactionIds)
        } catch {
            Log.multichainSwap.w("swap status refresh failed", error: error)
        }
        guard !Task.isCancelled, var trackedSwap = self.trackedSwap, trackedSwap.swap.id == swapId else {
            return false
        }
        if let activity {
            let previousStatus = trackedSwap.status
            trackedSwap.activity = activity
            self.trackedSwap = trackedSwap
            if trackedSwap.status != previousStatus {
                pinToast()
            }
        }
        guard trackedSwap.status == .pending else { return false }
        let limit = trackedSwap.activity == nil ? Self.unseenLimit : Self.pendingLimit
        guard now().timeIntervalSince(swap.date) < limit else {
            Log.multichainSwap.w(
                "swap status tracking given up",
                extraInfo: ["txHash": swap.txHash ?? "none", "isInHistory": "\(trackedSwap.activity != nil)"]
            )
            self.trackedSwap = nil
            unpinToast()
            return false
        }
        return true
    }

    func pinToast() {
        guard !isShowingDetails, let trackedSwap else { return }
        let sendAsset = trackedSwap.swap.sendAsset
        let title: String
        let avatar: ToastView.Model.Avatar
        let dismissRule: ToastPresenter.Configuration.DismissRule
        let feedback: ToastPresenter.Configuration.Feedback
        switch trackedSwap.status {
        case .pending:
            title = TKLocales.ActionTypes.swapping
            let image = AssetIdResolver.tkImageSource(
                for: sendAsset.asset.assetId,
                imageUrl: URL(string: sendAsset.asset.image),
                multichainEnabled: true
            ).image
            avatar = .image(image, isLoading: true)
            dismissRule = .none
            feedback = .neutral
        case .done:
            title = TKLocales.LiveActivity.swapped
            avatar = .icon(.TKUIKit.Icons.Size32.checkmarkCircle, tintColor: .Accent.green)
            dismissRule = .duration(Self.outcomeToastDuration)
            feedback = .success
        case .failed:
            title = TKLocales.MultichainSwap.Toast.failed
            avatar = .icon(.TKUIKit.Icons.Size32.xmarkCircle, tintColor: .Accent.orange)
            dismissRule = .duration(Self.outcomeToastDuration)
            feedback = .failure
        }
        var configuration = ToastPresenter.Configuration(
            title: title,
            subtitle: amountFormatter.format(
                amount: trackedSwap.swap.sendAmount,
                fractionDigits: sendAsset.asset.decimals,
                accessory: .tokenSymbol(sendAsset.swapDisplaySymbol),
                style: .compact
            ),
            avatar: avatar,
            showsDisclosure: true,
            feedback: feedback,
            dismissRule: dismissRule,
            topOffset: 8,
            allowsSwipeToDismiss: true,
            onTap: { [weak self] in
                // Taken down at once, so a second tap cannot open the details twice. The details
                // mark themselves open when they appear: UIKit may refuse to present them over a
                // sheet that is still closing.
                self?.unpinToast()
                self?.onOpenDetails?()
            }
        )
        if trackedSwap.status == .pending {
            configuration.onSwipeToDismiss = { [weak self] in
                self?.isPendingToastSwipedAway = true
            }
        } else {
            configuration.playsHaptic = SwapOutcomeHaptic.claim(transactionIds: trackedSwap.transactionIds)
        }
        pinToastConfiguration(configuration)
    }
}

extension MultichainSwapSentSwap {
    /// The swap's entry in history: the exchange its transaction belongs to, else the transaction's own.
    /// A relayed swap names no transaction, so it is the first exchange of the same amount of the same
    /// token since the swap was sent that no earlier swap was matched to.
    func activity(
        in activities: [MultichainActivity],
        excluding earlierSwapsTransactionIds: Set<String> = []
    ) -> MultichainActivity? {
        guard let txHash else {
            let earliestDate = date.addingTimeInterval(-60)
            return activities
                .filter {
                    $0.isExchange
                        && $0.outToken?.assetId == sendAsset.asset.assetId
                        && $0.outAmount.flatMap(MultichainActivityAmount.unsigned) == sendAmount
                        && $0.blockTime >= earliestDate
                        && earlierSwapsTransactionIds.isDisjoint(with: $0.txIds)
                }
                .min { $0.blockTime < $1.blockTime }
        }
        let transactionId = MultichainTransactionID.normalized(txHash, chain: sendAsset.asset.chain)
        let matches = activities.filter { activity in
            activity.txIds.contains {
                MultichainTransactionID.normalized($0, chain: activity.fromChain ?? activity.toChain) == transactionId
            }
        }
        let exchanges = matches.filter(\.isExchange)
        let candidates = exchanges.isEmpty ? matches : exchanges
        return candidates.first { $0.status != .pending } ?? candidates.first
    }
}
