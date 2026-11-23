@testable import App
import BigInt
import KeeperCore
import TKUIKit
import XCTest

@MainActor
final class MultichainSwapStatusTrackerTests: XCTestCase {
    func test_aSwapIsFoundByTheExchangeItsTransactionBelongsTo() {
        let swap = makeSwap(txHash: "0xABC")
        let sourceTransfer = activity(type: .send, status: .confirmed, txIds: ["eth:0xabc"])
        let exchange = activity(type: .bridge, status: .pending, txIds: ["0xabc", "btc:def"])

        XCTAssertEqual(swap.activity(in: [sourceTransfer, exchange]), exchange)
        XCTAssertEqual(swap.activity(in: [sourceTransfer]), sourceTransfer)
        XCTAssertNil(swap.activity(in: [activity(type: .swap, status: .pending, txIds: ["eth:0xabd"])]))
    }

    func test_aRelayedSwapIsTheFirstExchangeOfItsAmountSinceItWasSent() {
        let sentAt = Date(timeIntervalSince1970: 1_000_000)
        let swap = makeSwap(txHash: nil, date: sentAt)
        let earlier = activity(type: .swap, date: sentAt.addingTimeInterval(-600), outAmount: "-100")
        let otherAmount = activity(type: .swap, date: sentAt.addingTimeInterval(10), outAmount: "-99")
        let match = activity(type: .swap, date: sentAt.addingTimeInterval(20), outAmount: "-100")
        let later = activity(type: .swap, date: sentAt.addingTimeInterval(30), outAmount: "\u{2212}100")
        let transfer = activity(type: .send, date: sentAt.addingTimeInterval(5), outAmount: "-100")

        XCTAssertEqual(swap.activity(in: [later, transfer, match, otherAmount, earlier]), match)
    }

    func test_theSwapFollowsItsHistoryEntryToItsOutcome() async {
        let history = HistoryStub()
        await history.set([activity(type: .swap, status: .pending, txIds: ["eth:0xabc"])])
        let tracker = makeTracker(history: history)

        tracker.track(makeSwap(txHash: "0xabc"))
        tracker.setForeground(true)
        await waitUntil { tracker.trackedSwap?.activity != nil }
        XCTAssertEqual(tracker.trackedSwap?.status, .pending)

        await history.set([activity(type: .swap, status: .dropped, txIds: ["eth:0xabc"])])
        tracker.historyDidChange(multichainWalletId: "wallet")
        await waitUntil { tracker.trackedSwap?.status == .failed }
        XCTAssertEqual(tracker.trackedSwap?.status, .failed)
    }

    func test_aSwapHistoryDoesNotShowIsGivenUpAfterTenMinutes() async {
        let sentAt = Date()
        let tracker = makeTracker(history: HistoryStub(), now: { sentAt.addingTimeInterval(11 * 60) })

        tracker.track(makeSwap(txHash: "0xabc", date: sentAt))
        tracker.setForeground(true)
        await waitUntil { tracker.trackedSwap == nil }

        XCTAssertNil(tracker.trackedSwap)
    }

    func test_aSwapInHistoryIsFollowedPastTenMinutes() async {
        let sentAt = Date()
        let history = HistoryStub()
        await history.set([activity(type: .swap, status: .pending, txIds: ["eth:0xabc"])])
        let tracker = makeTracker(history: history, now: { sentAt.addingTimeInterval(11 * 60) })

        tracker.track(makeSwap(txHash: "0xabc", date: sentAt))
        tracker.setForeground(true)
        await waitUntil { tracker.trackedSwap?.activity != nil }

        XCTAssertEqual(tracker.trackedSwap?.status, .pending)
    }

    func test_anAnswerForASwapReplacedMeanwhileIsDropped() async {
        let history = HistoryStub()
        await history.set([activity(type: .swap, status: .confirmed, txIds: ["eth:0xabc"])])
        await history.hold()
        let tracker = makeTracker(history: history)
        tracker.track(makeSwap(txHash: "0xabc"))
        tracker.setForeground(true)
        await history.waitUntilLoading()

        let newer = makeSwap(txHash: "0xdef")
        tracker.track(newer)
        await history.release()
        await waitUntil(timeout: 0.3) { tracker.trackedSwap?.activity != nil }

        XCTAssertEqual(tracker.trackedSwap?.swap.id, newer.id)
        XCTAssertNil(tracker.trackedSwap?.activity)
    }

    func test_aRelayedSwapRepeatedSoonAfterSkipsTheExchangeOfTheSwapBeforeIt() async {
        let sentAt = Date()
        let firstExchange = activity(
            type: .swap,
            status: .failed,
            date: sentAt.addingTimeInterval(5),
            txIds: ["eth:0x1"],
            outAmount: "-100"
        )
        let history = HistoryStub()
        await history.set([firstExchange])
        let tracker = makeTracker(history: history)
        tracker.track(makeSwap(txHash: nil, date: sentAt))
        tracker.setForeground(true)
        await waitUntil { tracker.trackedSwap?.status == .failed }

        tracker.track(makeSwap(txHash: nil, date: sentAt.addingTimeInterval(30)))
        tracker.setForeground(true)
        await waitUntil(timeout: 0.3) { tracker.trackedSwap?.activity != nil }
        XCTAssertNil(tracker.trackedSwap?.activity)

        let repeatExchange = activity(
            type: .swap,
            status: .confirmed,
            date: sentAt.addingTimeInterval(40),
            txIds: ["eth:0x2"],
            outAmount: "-100"
        )
        await history.set([repeatExchange, firstExchange])
        tracker.historyDidChange(multichainWalletId: "wallet")
        await waitUntil { tracker.trackedSwap?.activity != nil }

        XCTAssertEqual(tracker.trackedSwap?.activity, repeatExchange)
    }

    func test_aPendingToastSwipedAwayIsNotPinnedAgainWhenTheDetailsClose() {
        let toasts = ToastRecorder()
        let tracker = makeTracker(history: HistoryStub(), toasts: toasts)
        tracker.track(makeSwap(txHash: "0xabc"))
        tracker.detailsDidOpen()
        tracker.detailsDidClose()
        XCTAssertEqual(toasts.pinned.count, 2)

        toasts.pinned.last?.onSwipeToDismiss?()
        tracker.detailsDidOpen()
        tracker.detailsDidClose()

        XCTAssertEqual(toasts.pinned.count, 2)
    }

    func test_aPendingToastSwipedAwayGivesWayToTheSwapsOutcome() async {
        let history = HistoryStub()
        let toasts = ToastRecorder()
        let tracker = makeTracker(history: history, toasts: toasts)
        tracker.track(makeSwap(txHash: "0xabc"))
        toasts.pinned.last?.onSwipeToDismiss?()

        await history.set([activity(type: .swap, status: .confirmed, txIds: ["eth:0xabc"])])
        tracker.setForeground(true)
        await waitUntil { tracker.trackedSwap?.status == .done }

        XCTAssertEqual(toasts.pinned.count, 2)
        XCTAssertEqual(toasts.pinned.last?.feedback, .success)
    }

    func test_aNewSwapsPendingToastComesBackAfterTheLastOneWasSwipedAway() {
        let toasts = ToastRecorder()
        let tracker = makeTracker(history: HistoryStub(), toasts: toasts)
        tracker.track(makeSwap(txHash: "0xabc"))
        toasts.pinned.last?.onSwipeToDismiss?()

        tracker.track(makeSwap(txHash: "0xdef"))
        tracker.detailsDidOpen()
        tracker.detailsDidClose()

        XCTAssertEqual(toasts.pinned.count, 3)
    }
}

private extension MultichainSwapStatusTrackerTests {
    func makeTracker(
        history: HistoryStub,
        toasts: ToastRecorder = ToastRecorder(),
        now: @escaping () -> Date = Date.init
    ) -> MultichainSwapStatusTracker {
        MultichainSwapStatusTracker(
            loadActivities: { _ in await history.load() },
            amountFormatter: AmountFormatter(),
            now: now,
            pinToast: { toasts.pinned.append($0) },
            unpinToast: { toasts.unpinCount += 1 }
        )
    }

    func makeSwap(txHash: String?, date: Date = Date()) -> MultichainSwapSentSwap {
        MultichainSwapSentSwap(
            multichainState: MultichainWalletState(walletId: "wallet", addresses: []),
            txHash: txHash,
            sendAsset: asset("ETH", chain: .eth),
            receiveAsset: asset("BTC", chain: .btc),
            sendAmount: 100,
            estimatedReceiveAmount: 28,
            date: date
        )
    }

    func asset(_ symbol: String, chain: MultichainChain) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "\(chain.rawValue)/mainnet/coin",
                chain: chain,
                name: symbol,
                symbol: symbol,
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: .zero
        )
    }

    func activity(
        type: MultichainActivityType,
        status: MultichainActivityStatus = .pending,
        date: Date = Date(),
        txIds: [String] = [],
        outAmount: String? = nil
    ) -> MultichainActivity {
        MultichainActivity(
            activityType: type,
            status: status,
            blockTime: date,
            blockNumber: nil,
            fromChain: .eth,
            toChain: .btc,
            walletAddress: nil,
            direction: .outgoing,
            fromAddress: nil,
            toAddress: nil,
            outToken: asset("ETH", chain: .eth).asset,
            outAmount: outAmount,
            outAmountUsd: nil,
            inToken: nil,
            inAmount: nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: txIds,
            isRead: nil
        )
    }

    func waitUntil(timeout: TimeInterval = 2, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// The toasts the tracker pins, in order, so a test can swipe one away through its configuration.
private final class ToastRecorder {
    var pinned = [ToastPresenter.Configuration]()
    var unpinCount = 0
}

private actor HistoryStub {
    private var activities: [MultichainActivity] = []
    private var isHeld = false
    private var isLoading = false
    private var heldLoad: CheckedContinuation<Void, Never>?

    func set(_ activities: [MultichainActivity]) {
        self.activities = activities
    }

    func hold() {
        isHeld = true
    }

    func release() {
        isHeld = false
        heldLoad?.resume()
        heldLoad = nil
    }

    func waitUntilLoading() async {
        while !isLoading {
            await Task.yield()
        }
    }

    func load() async -> [MultichainActivity] {
        isLoading = true
        if isHeld {
            await withCheckedContinuation { heldLoad = $0 }
        }
        return activities
    }
}
