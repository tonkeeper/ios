import ChainKit
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsAutoCloseRebaseTests: XCTestCase {
    func testOnlyATerminalEntryReportsItsFilledSize() {
        XCTAssertNil(PerpsAutoCloseRebase.finalFilledBase([
            .init(order_index: 1, status: "open", filled_base: "0.4"),
        ]))
        XCTAssertNil(PerpsAutoCloseRebase.finalFilledBase([]))
        XCTAssertNil(PerpsAutoCloseRebase.finalFilledBase([.init(order_index: 1, status: "filled")]))
        XCTAssertNil(PerpsAutoCloseRebase.finalFilledBase([.init(order_index: 1, status: "filled", filled_base: "nan")]))
        XCTAssertEqual(PerpsAutoCloseRebase.finalFilledBase([
            .init(order_index: 1, status: "filled", filled_base: "1"),
        ]), 1)
        XCTAssertEqual(PerpsAutoCloseRebase.finalFilledBase([
            .init(order_index: 1, status: "canceled", filled_base: "0.4"),
        ]), 0.4)
        XCTAssertEqual(PerpsAutoCloseRebase.finalFilledBase([
            .init(order_index: 1, status: "rejected", filled_base: "0"),
        ]), 0)
    }

    func testLongAndShortLevelsUseSignedROIAndLeverage() throws {
        for (side, roi, expected): (PerpsTradeSide, Double, Int64) in [
            (.long, 20, 204_000), (.long, -10, 198_000),
            (.short, 20, 196_000), (.short, -10, 202_000),
        ] {
            let rebase = PerpsPendingAutoCloseRebase(parentOperationId: "open", parentClientOrderIndex: 1, originalTriggerPrice: 2100, roiPercent: roi, leverage: 10)
            XCTAssertEqual(try PerpsAutoCloseRebase.targetPrice(rebase, side: side, entryPrice: 2000, priceDecimals: 2, tick: 1), expected)
        }
    }

    func testRoundsToTheMarketTickAndRejectsUnrepresentableTargets() throws {
        let rebase = PerpsPendingAutoCloseRebase(parentOperationId: "open", parentClientOrderIndex: 1, originalTriggerPrice: 2100, roiPercent: 20, leverage: 10)
        XCTAssertEqual(try PerpsAutoCloseRebase.targetPrice(rebase, side: .long, entryPrice: 2000.13, priceDecimals: 2, tick: 25), 204_025)
        let flatROI = PerpsPendingAutoCloseRebase(parentOperationId: "open", parentClientOrderIndex: 1, originalTriggerPrice: 100, roiPercent: 0, leverage: 10)
        XCTAssertEqual(try PerpsAutoCloseRebase.targetPrice(flatROI, side: .long, entryPrice: 100.045, priceDecimals: 2, tick: 10), 10000)
        XCTAssertThrowsError(try PerpsAutoCloseRebase.targetPrice(rebase, side: .long, entryPrice: .infinity, priceDecimals: 2, tick: 1))
        XCTAssertThrowsError(try PerpsAutoCloseRebase.targetPrice(rebase, side: .long, entryPrice: 2000, priceDecimals: 2, tick: 0))
        let negative = PerpsPendingAutoCloseRebase(parentOperationId: "open", parentClientOrderIndex: 1, originalTriggerPrice: 100, roiPercent: -200, leverage: 1)
        XCTAssertThrowsError(try PerpsAutoCloseRebase.targetPrice(negative, side: .long, entryPrice: 2000, priceDecimals: 2, tick: 1))
    }

    func testARejectedEntryDropsItsCorrectionsButKeepsOtherOperations() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directory)
        for (id, parent) in [("correction", "failed"), ("other", "other-entry")] {
            _ = try await journal.savePendingIfAbsentWithStatus(.init(
                operationId: id, walletId: "wallet", marketId: 1, side: .long,
                payload: .autoCloseRebase(.init(parentOperationId: parent, parentClientOrderIndex: 1, originalTriggerPrice: 2100, roiPercent: 20, leverage: 10))
            ))
        }
        try await journal.removePending(operationId: "failed", includingFollowUps: true)
        let remaining = try await journal.allPending()
        XCTAssertEqual(remaining.map(\.operationId), ["other"])
    }

    func testASettledEntryStartsOnlyItsOwnCorrectionsSettleWindow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directory)
        for (id, parent) in [("correction", "entry"), ("other", "other-entry")] {
            _ = try await journal.savePendingIfAbsentWithStatus(.init(
                operationId: id, walletId: "wallet", marketId: 1, side: .long,
                payload: .autoCloseRebase(.init(parentOperationId: parent, parentClientOrderIndex: 1, originalTriggerPrice: 2100, roiPercent: 20, leverage: 10))
            ))
        }
        let before = Int64(Date().timeIntervalSince1970 * 1000)
        try await journal.removePending(operationId: "entry")
        func settledAt(_ id: String) async throws -> Int64? {
            guard case let .autoCloseRebase(rebase) = try await journal.pending(operationId: id)?.payload else { return nil }
            return rebase.entrySettledAtMillis
        }
        let settled = try await settledAt("correction")
        let untouched = try await settledAt("other")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(settled), before)
        XCTAssertNil(untouched)
    }

    func testSignedEntryAndItsCorrectionsArePersistedAtomicallyAndTargetsStayFrozen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        func journal() -> PerpsPendingJournal {
            .init(walletId: "wallet", environment: "test", directoryURL: directory)
        }
        let parent = PerpsPendingTradingAction(operationId: "open", walletId: "wallet", marketId: 1, side: .long, payload: .open(limitPrice: nil))
        let correction = PerpsPendingTradingAction(
            operationId: "rebase", walletId: "wallet", marketId: 1, side: .long,
            payload: .autoCloseRebase(.init(parentOperationId: "open", parentClientOrderIndex: 1, originalTriggerPrice: 2100, roiPercent: 20, leverage: 10)),
            orderRefs: [.init(role: .takeProfit, clientOrderIndex: 2)]
        )
        let step = PerpsPendingSignedStep(stepId: "open", attemptId: "a", nonce: 1, transactionExpiryUnixMs: 1000, txType: 14, txInfo: "signed", txHash: "hash", state: .signed)
        do {
            try await journal().appendSignedStep(operationId: "missing", step: step, refs: [], followUps: [correction])
            XCTFail("a failed parent write must not save its correction")
        } catch {}
        let before = try await journal().allPending()
        XCTAssertTrue(before.isEmpty)
        _ = try await journal().savePendingIfAbsentWithStatus(parent)
        try await journal().appendSignedStep(operationId: "open", step: step, refs: [], followUps: [correction])
        try await journal().removePending(operationId: "open")
        try await journal().setRebaseTarget(operationId: "rebase", price: 2040)
        try await journal().setRebaseTarget(operationId: "rebase", price: 2050)
        let restored = try await journal().allPending()
        XCTAssertEqual(restored.count, 1)
        guard case let .autoCloseRebase(rebase) = restored.first?.payload else { return XCTFail("lost correction") }
        XCTAssertEqual(rebase.targetPrice, 2040)
        XCTAssertEqual(rebase.roiPercent, 20)
        XCTAssertFalse(restored[0].blocksPositionOrders(now: 0))
    }
}
