import Foundation
@testable import KeeperCore
import PerpsModels
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

    func testAnUnreadableDocumentIsSetAsideAsFundingEvidenceWhileTradingGoesOn() async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let damaged = Data("not-json".utf8)
        try damaged.write(to: journalFileURL())
        let journal = makeJournal()

        let pendings = try await journal.allPending()
        _ = try await journal.savePendingIfAbsentWithStatus(makePending(operationId: "new", createdAtMillis: 1))

        let afterWrite = try await journal.allPending()
        XCTAssertTrue(pendings.isEmpty)
        XCTAssertEqual(afterWrite.count, 1)
        XCTAssertEqual(try FileManager.default.setAsideJournals(of: journalFileURL()), [damaged])
        do {
            _ = try await journal.allFunding()
            XCTFail("the evidence may hold an unresolved payment")
        } catch {
            XCTAssertEqual(error as? PerpsPendingJournalError, .fundingSetAside)
        }
    }

    func testOneUnreadableRecordDoesNotCostTheOthers() async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsentWithStatus(makePending(operationId: "kept", createdAtMillis: 1))
        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: journalFileURL()))
        var root = try XCTUnwrap(document as? [String: Any])
        var records = try XCTUnwrap(root["pending"] as? [String: Any])
        records["broken"] = ["operationId": "broken"]
        root["pending"] = records
        try JSONSerialization.data(withJSONObject: root).write(to: journalFileURL())

        let pendings = try await makeJournal().allPending()

        XCTAssertEqual(pendings.map(\.operationId), ["kept"])
    }

    func testCleanupDropsASignedPendingOnceItsTransactionCanNoLongerLand() async throws {
        let journal = makeJournal()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        _ = try await journal.savePendingIfAbsentWithStatus(
            makePending(operationId: "expired", createdAtMillis: nowMillis - 49 * 60 * 60 * 1000)
        )
        try await journal.appendSignedStep(
            operationId: "expired",
            step: PerpsPendingSignedStep(
                stepId: "open",
                attemptId: "attempt",
                nonce: 1,
                transactionExpiryUnixMs: nowMillis - 25 * 60 * 60 * 1000,
                txType: 14,
                txInfo: "payload",
                txHash: "hash",
                state: .unknown
            ),
            refs: []
        )

        try await journal.cleanupPending()

        let remaining = try await journal.allPending()
        XCTAssertEqual(remaining.count, 0)
    }

    func testCleanupDropsOnlyStalePendingActions() async throws {
        let journal = makeJournal()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        for pending in [
            makePending(operationId: "fresh", createdAtMillis: nowMillis),
            makePending(operationId: "stale", createdAtMillis: nowMillis - 25 * 60 * 60 * 1000),
            makePending(operationId: "signed", createdAtMillis: nowMillis - 25 * 60 * 60 * 1000),
        ] {
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
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
            _ = try await journal.savePendingIfAbsentWithStatus(pending)
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

        _ = try await journal.savePendingIfAbsentWithStatus(pending)
        let restored = try await journal.pending(operationId: pending.operationId)

        XCTAssertEqual(restored, pending)
    }

    func testOrderRefsAccumulateAcrossStepsBeforeTheirSend() async throws {
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsentWithStatus(makePending(operationId: "op", createdAtMillis: 1))

        try await journal.appendSignedStep(
            operationId: "op",
            step: makeSignedStep(stepId: "open"),
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
        )
        try await journal.appendSignedStep(
            operationId: "op",
            step: makeSignedStep(stepId: "autoClose"),
            refs: [
                PerpsPendingOrderRef(role: .takeProfit, clientOrderIndex: 12),
                PerpsPendingOrderRef(role: .stopLoss, clientOrderIndex: 13),
            ]
        )
        try await journal.appendSignedStep(
            operationId: "op",
            step: makeSignedStep(stepId: "open", state: .accepted),
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
        )

        let restored = try await journal.pending(operationId: "op")
        XCTAssertEqual(restored?.orderRefs?.count, 3)
        XCTAssertEqual(restored?.positionOrderRef?.clientOrderIndex, 11)
        XCTAssertEqual(restored?.triggerOrderRefs.map(\.clientOrderIndex), [12, 13])
    }

    func testSignedStepIsDurableAndStateCanAdvance() async throws {
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsentWithStatus(makePending(operationId: "signed", createdAtMillis: 1))
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

    func testASignedStepForAnUnknownOperationFailsLoudly() async throws {
        let journal = makeJournal()

        do {
            try await journal.appendSignedStep(
                operationId: "missing",
                step: makeSignedStep(stepId: "open"),
                refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 11)]
            )
            XCTFail("journalling a step for a missing operation must fail")
        } catch {}
    }
}

private extension PerpsPendingJournalTests {
    func makeSignedStep(stepId: String, state: PerpsPendingStepState = .signed) -> PerpsPendingSignedStep {
        PerpsPendingSignedStep(
            stepId: stepId,
            attemptId: "attempt",
            nonce: 1,
            transactionExpiryUnixMs: 1,
            txType: 14,
            txInfo: "payload",
            txHash: "hash",
            state: state
        )
    }

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

extension FileManager {
    /// Contents of the documents a journal set aside, next to its file.
    func setAsideJournals(of journalURL: URL) throws -> [Data] {
        let directory = journalURL.deletingLastPathComponent()
        return try contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("\(journalURL.lastPathComponent).funding-unreadable") }
            .map { try Data(contentsOf: directory.appendingPathComponent($0)) }
    }
}
