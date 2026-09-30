import Foundation
@testable import KeeperCore
import XCTest

final class PerpsPendingJournalTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsPendingJournalTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testCorruptDocumentFailsLoudly() async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: journalFileURL())

        do {
            _ = try await makeJournal().allPending()
            XCTFail("corrupt pending journal must not be treated as empty")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testCleanupDropsOnlyStalePendingActions() async throws {
        let journal = makeJournal()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        for pending in [
            makePending(operationId: "fresh", createdAtMillis: nowMillis),
            makePending(operationId: "stale", createdAtMillis: nowMillis - 25 * 60 * 60 * 1000),
            makePending(operationId: "signed", createdAtMillis: nowMillis - 25 * 60 * 60 * 1000),
        ] {
            _ = try await journal.savePendingIfAbsent(pending)
        }
        try await journal.appendSignedStep(
            operationId: "signed",
            step: PerpsPendingSignedStep(
                stepId: "open",
                attemptId: "attempt",
                nonce: 1,
                transactionExpiryUnixMs: nowMillis,
                txType: 14,
                txInfo: "payload",
                txHash: "hash",
                state: .unknown
            ),
            refs: []
        )

        try await journal.cleanupPending()

        let fresh = try await journal.pending(operationId: "fresh")
        let stale = try await journal.pending(operationId: "stale")
        let signed = try await journal.pending(operationId: "signed")
        let remaining = try Set(await journal.allPending().map(\.operationId))
        XCTAssertNotNil(fresh)
        XCTAssertNil(stale)
        XCTAssertNotNil(signed)
        XCTAssertEqual(remaining, Set(["fresh", "signed"]))
    }

    func testCleanupKeepsAPendingWhoseOrderCanStillBeResting() async throws {
        let journal = makeJournal()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let createdADayAndAnHourAgo = nowMillis - 25 * 60 * 60 * 1000
        for pending in [
            makePending(
                operationId: "resting",
                createdAtMillis: createdADayAndAnHourAgo,
                expiresAtMillis: nowMillis + 27 * 24 * 60 * 60 * 1000
            ),
            makePending(
                operationId: "expired",
                createdAtMillis: createdADayAndAnHourAgo,
                expiresAtMillis: createdADayAndAnHourAgo
            ),
        ] {
            _ = try await journal.savePendingIfAbsent(pending)
        }

        try await journal.cleanupPending()

        let remaining = try Set(await journal.allPending().map(\.operationId))
        XCTAssertEqual(remaining, Set(["resting"]))
    }

    func testPendingLimitOrderChangeRoundTripsThroughTheDurableJournal() async throws {
        let journal = makeJournal()
        let pending = PerpsPendingTradingAction(
            operationId: "modify-limit",
            createdAtMillis: 123,
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: .limitOrderChange(PerpsPendingLimitOrderChange(
                orderIndex: 77,
                kind: .modify,
                limitPrice: 67250.12
            ))
        )

        _ = try await journal.savePendingIfAbsent(pending)
        let restored = try await journal.pending(operationId: pending.operationId)

        XCTAssertEqual(restored, pending)
    }

    func testOrderRefsAccumulateAcrossStepsBeforeTheirSend() async throws {
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsent(makePending(operationId: "op", createdAtMillis: 1))

        try await journal.appendOrderRefs(
            operationId: "op",
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
        )
        try await journal.appendOrderRefs(
            operationId: "op",
            refs: [
                PerpsPendingOrderRef(role: .takeProfit, clientOrderIndex: 12),
                PerpsPendingOrderRef(role: .stopLoss, clientOrderIndex: 13),
            ]
        )
        try await journal.appendOrderRefs(
            operationId: "op",
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
        )

        let restored = try await journal.pending(operationId: "op")
        XCTAssertEqual(restored?.orderRefs?.count, 3)
        XCTAssertEqual(restored?.positionOrderRef?.clientOrderIndex, 11)
        XCTAssertEqual(restored?.triggerOrderRefs.map(\.clientOrderIndex), [12, 13])
    }

    func testSignedStepIsDurableAndStateCanAdvance() async throws {
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsent(makePending(operationId: "signed", createdAtMillis: 1))
        let signed = PerpsPendingSignedStep(
            stepId: "open",
            attemptId: "attempt",
            nonce: 7,
            transactionExpiryUnixMs: 99,
            txType: 42,
            txInfo: "payload",
            txHash: "hash",
            state: .signed
        )

        try await journal.appendSignedStep(
            operationId: "signed",
            step: signed,
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
        )
        try await journal.appendSignedStep(
            operationId: "signed",
            step: signed.withState(.accepted),
            refs: []
        )

        let restored = try await journal.pending(operationId: "signed")
        XCTAssertEqual(restored?.signedSteps, [signed.withState(.accepted)])
        XCTAssertEqual(restored?.positionOrderRef?.clientOrderIndex, 11)
    }

    func testOrderRefsForAnUnknownOperationFailLoudly() async throws {
        let journal = makeJournal()

        do {
            try await journal.appendOrderRefs(
                operationId: "missing",
                refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
            )
            XCTFail("appending refs for a missing operation must fail")
        } catch {}
    }
}

private extension PerpsPendingJournalTests {
    func makeJournal() -> PerpsPendingJournal {
        PerpsPendingJournal(
            walletId: "wallet",
            environment: "test",
            directoryURL: directoryURL
        )
    }

    func makePending(
        operationId: String,
        createdAtMillis: Int64,
        expiresAtMillis: Int64? = nil
    ) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: operationId,
            createdAtMillis: createdAtMillis,
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: .open(limitPrice: nil),
            expiresAtMillis: expiresAtMillis
        )
    }

    func journalFileURL() -> URL {
        let scope = Data("wallet/test".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directoryURL.appendingPathComponent("\(scope).json")
    }
}
