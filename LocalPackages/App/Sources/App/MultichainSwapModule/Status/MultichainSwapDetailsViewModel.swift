import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

/// Bound to one swap: it keeps showing that swap's last state when the tracker gives it up or moves
/// on to a newer one.
@MainActor
final class MultichainSwapDetailsViewModel: ObservableObject {
    @Published private(set) var state: MultichainSwapDetailsViewState

    private weak var tracker: MultichainSwapStatusTracker?
    private var updates: AnyCancellable?

    init(
        tracker: MultichainSwapStatusTracker,
        trackedSwap: MultichainSwapTrackedSwap,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter
    ) {
        self.tracker = tracker
        let historyDetails = MultichainTransactionDetailsModelBuilder(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            transactionButtonProvider: { _ in nil },
            hidesAmounts: { false }
        )
        let makeState = { (trackedSwap: MultichainSwapTrackedSwap) in
            MultichainSwapDetailsViewState(
                trackedSwap: trackedSwap,
                amountFormatter: amountFormatter,
                dateFormatter: dateFormatter,
                historyDetails: historyDetails
            )
        }
        state = makeState(trackedSwap)
        let swapId = trackedSwap.swap.id
        updates = tracker.$trackedSwap
            .compactMap { $0 }
            .filter { $0.swap.id == swapId }
            .sink { [weak self] in
                self?.state = makeState($0)
            }
    }

    func didAppear() {
        tracker?.detailsDidOpen()
    }

    func didDisappear() {
        tracker?.detailsDidClose()
    }
}

struct MultichainSwapDetailsViewContainer: View {
    @ObservedObject var viewModel: MultichainSwapDetailsViewModel
    let onClose: () -> Void
    let onOpenTransaction: (URL, String?) -> Void
    let onCopyTransactionHash: (String) -> Void

    var body: some View {
        MultichainSwapDetailsView(
            state: viewModel.state,
            onClose: onClose,
            onOpenTransaction: onOpenTransaction,
            onCopyTransactionHash: onCopyTransactionHash
        )
        .onAppear(perform: viewModel.didAppear)
        .onDisappear(perform: viewModel.didDisappear)
    }
}

extension MultichainSwapDetailsViewState {
    init(
        trackedSwap: MultichainSwapTrackedSwap,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        historyDetails: MultichainTransactionDetailsModelBuilder
    ) {
        let swap = trackedSwap.swap
        let activity = trackedSwap.activity
        let receivedAmount = activity.flatMap { activity -> BigUInt? in
            guard trackedSwap.status == .done,
                  activity.inToken?.assetId == swap.receiveAsset.asset.assetId
            else {
                return nil
            }
            return activity.inAmount.flatMap(MultichainActivityAmount.unsigned)
        }
        let status: Status = switch trackedSwap.status {
        case .pending: .pending
        case .done: .done
        case .failed: .failed
        }
        self.init(
            send: Amount(
                value: amountFormatter.format(
                    amount: swap.sendAmount,
                    fractionDigits: swap.sendAsset.asset.decimals,
                    accessory: .tokenSymbol(swap.sendAsset.swapDisplaySymbol),
                    style: .compact
                ),
                avatarSource: swap.sendAsset.swapAvatarSource
            ),
            receive: Amount(
                value: amountFormatter.format(
                    amount: receivedAmount ?? swap.estimatedReceiveAmount,
                    fractionDigits: swap.receiveAsset.asset.decimals,
                    accessory: .tokenSymbol(swap.receiveAsset.swapDisplaySymbol),
                    style: .compact
                ),
                avatarSource: swap.receiveAsset.swapAvatarSource
            ),
            date: dateFormatter.string(from: activity?.blockTime ?? swap.date),
            networkFee: activity.flatMap { Self.networkFee(of: $0, historyDetails: historyDetails) },
            status: status,
            transactions: Self.transactions(of: trackedSwap)
        )
    }
}

private extension MultichainSwapDetailsViewState {
    /// What the swap's history entry says it paid, put as the history details put it.
    static func networkFee(
        of activity: MultichainActivity,
        historyDetails: MultichainTransactionDetailsModelBuilder
    ) -> String? {
        guard case let .fee(_, amount, _) = historyDetails.feeRow(activity: activity) else {
            return nil
        }
        return amount
    }

    /// The transaction on the sending chain and, for a swap across chains that has not failed, the one
    /// on the receiving chain, awaited while the swap is pending.
    static func transactions(of trackedSwap: MultichainSwapTrackedSwap) -> [Transaction] {
        guard let activity = trackedSwap.activity else {
            return []
        }
        let links = activity.explorerLinks.filter { ["https", "http"].contains($0.url.scheme?.lowercased()) }
        let sent = links.first { $0.chain == activity.fromChain }
        let received = links.first { $0.chain == activity.toChain && $0 != sent }
        var transactions = sent.map { [transaction(title: TKLocales.ActionTypes.sent, link: $0)] } ?? []
        let swap = trackedSwap.swap
        guard swap.sendAsset.asset.chain != swap.receiveAsset.asset.chain, trackedSwap.status != .failed else {
            return transactions
        }
        if let received {
            transactions.append(transaction(title: TKLocales.ActionTypes.received, link: received))
        } else if trackedSwap.status == .pending, sent != nil {
            transactions.append(.receiving)
        }
        return transactions
    }

    static func transaction(title: String, link: MultichainActivityExplorerLink) -> Transaction {
        let hash = link.transactionId.split(separator: ":", maxSplits: 1).last.map(String.init) ?? link.transactionId
        let button = MultichainTransactionDetailsModel.TransactionButton(
            title: TKThemedText(spans: [
                .init("\(title) ", color: .buttonSecondaryForeground),
                .init(String(hash.prefix(8)), color: .textTertiary),
            ]),
            url: link.url,
            browserTitle: nil
        )
        return .link(button, hash: hash)
    }
}
