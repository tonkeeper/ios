import Foundation
@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsPendingJournalFundingTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsPendingJournalFundingTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testLegacyDepositStagesAndSignedBytesSurviveRoundTrip() async throws {
        let stages = ["sourceSigned", "sourceSending", "sourceUnknown", "awaitingDelivery", "readyForGateway", "approvalPending", "gatewaySigned", "gatewaySending", "gatewayUnknown"]
        let journal = makeJournal()
        for stage in stages {
            _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: stage))
        }
        try rewriteDocument { document in
            document["version"] = 1
            var funding = document["funding"] as! [String: [String: Any]]
            for stage in stages {
                var details = funding[stage]!["details"] as! [String: [String: Any]]
                var wrapper = details["deposit"]!
                var deposit = wrapper["_0"] as! [String: Any]
                deposit["stage"] = stage
                deposit["gatewayAmountUnits"] = "2400000"
                deposit["gatewayStep"] = ["stepId": "gateway", "attemptId": "attempt", "chainId": 1, "sender": "sender", "nonce": 7, "signedTransaction": "0xbytes", "txHash": "0xhash", "state": "unknown"]
                wrapper["_0"] = deposit
                details["deposit"] = wrapper
                funding[stage]!["details"] = details
            }
            document["funding"] = funding
        }
        let restored = try await journal.allFunding()
        XCTAssertEqual(Set(restored.compactMap { $0.deposit?.stage.rawValue }), Set(stages))
        XCTAssertTrue(restored.allSatisfy { $0.deposit?.gatewayStep?.signedTransaction == "0xbytes" })
        XCTAssertTrue(restored.allSatisfy { $0.deposit?.gatewayAmountUnits == "2400000" })
        _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "new"))
        let reopened = try await makeJournal().allFunding()
        XCTAssertEqual(reopened.count, stages.count + 1)
    }

    func testDocumentWrittenBeforeFundingKeepsItsTradingActions() async throws {
        let journal = makeJournal()
        _ = try await journal.savePendingIfAbsentWithStatus(makeTradingPending())
        try rewriteDocument { document in
            document.removeValue(forKey: "version")
            document.removeValue(forKey: "funding")
        }

        let pending = try await journal.allPending()
        let funding = try await journal.allFunding()

        XCTAssertEqual(pending.map(\.operationId), ["trade"])
        XCTAssertTrue(funding.isEmpty)
    }

    func testBrokenTradingRecordCanBeSalvagedWithoutLosingFunding() async throws {
        let journal = makeJournal()
        let deposit = makeDeposit(operationId: "deposit", stage: .registrationPending)
        _ = try await journal.saveFundingIfAbsent(deposit)
        try rewriteDocument { document in
            document["pending"] = ["broken": ["operationId": "broken"]]
        }

        let funding = try await journal.allFunding()
        XCTAssertEqual(funding, [deposit])
        _ = try await journal.savePendingIfAbsentWithStatus(makeTradingPending())
        let restored = try await makeJournal().allFunding()
        XCTAssertEqual(restored, [deposit])
    }

    func testDocumentFromANewerVersionIsRefusedRatherThanRewritten() async throws {
        let journal = makeJournal()
        _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "deposit"))
        try rewriteDocument { $0["version"] = 3 }

        do {
            _ = try await journal.allFunding()
            XCTFail("a document this build cannot represent must not read as empty")
        } catch {
            XCTAssertEqual(error as? PerpsPendingJournalError, .unsupportedVersion(3))
        }
    }

    func testSavingTheSameOperationTwiceKeepsTheFirstRecord() async throws {
        let journal = makeJournal()
        let first = makeDeposit(operationId: "deposit", sourceAmountUnits: "25000000")

        let initial = try await journal.saveFundingIfAbsent(first)
        let repeated = try await journal.saveFundingIfAbsent(
            makeDeposit(operationId: "deposit", sourceAmountUnits: "40000000")
        )

        XCTAssertTrue(initial.inserted)
        XCTAssertFalse(repeated.inserted)
        XCTAssertEqual(repeated.operation, first)
    }

    func testMissingDictionariesBlockFundingButNotTrading() async throws {
        let journal = makeJournal()
        _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "deposit", stage: .registrationPending))
        let original = try Data(contentsOf: journalFileURL())
        for key in ["pending", "funding"] {
            for name in try FileManager.default.contentsOfDirectory(atPath: directoryURL.path) {
                try FileManager.default.removeItem(at: directoryURL.appendingPathComponent(name))
            }
            try original.write(to: journalFileURL())
            try rewriteDocument { $0.removeValue(forKey: key) }
            let damaged = try Data(contentsOf: journalFileURL())

            do {
                _ = try await journal.allFunding()
                XCTFail("a missing \(key) dictionary must fail closed for funding")
            } catch {
                XCTAssertEqual(error as? PerpsPendingJournalError, .fundingSetAside)
            }
            _ = try await journal.savePendingIfAbsentWithStatus(makeTradingPending())
            XCTAssertEqual(try FileManager.default.setAsideJournals(of: journalFileURL()), [damaged])
        }
    }

    func testAnUnreadableFundingRecordIsSetAsideWhileTheReadableOnesAreStillFollowed() async throws {
        let journal = makeJournal()
        let kept = makeDeposit(operationId: "kept", stage: .registrationPending)
        _ = try await journal.saveFundingIfAbsent(kept)
        _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "broken", stage: .registrationPending))
        try rewriteDocument { document in
            var funding = document["funding"] as! [String: [String: Any]]
            funding["broken"]!.removeValue(forKey: "details")
            document["funding"] = funding
        }
        let damaged = try Data(contentsOf: journalFileURL())

        let cleaned = try await journal.cleanupPending()

        XCTAssertEqual(cleaned.funding, [kept])
        XCTAssertFalse(cleaned.fundingIntact)
        XCTAssertEqual(try FileManager.default.setAsideJournals(of: journalFileURL()), [damaged])
    }

    /// The journal fails closed for funding, so a record another build wrote — a newer one
    /// naming a field this build has never heard of, an older one leaving out an optional —
    /// has to decode here, or one deposit takes every trading operation down with it.
    func testFundingWrittenByAnotherBuildStillLoadsAlongsideTrading() async throws {
        let journal = makeJournal()
        let deposit = makeDeposit(operationId: "deposit")
        _ = try await journal.saveFundingIfAbsent(deposit)
        _ = try await journal.savePendingIfAbsentWithStatus(makeTradingPending())
        try rewriteDocument { document in
            var funding = document["funding"] as! [String: [String: Any]]
            var operation = funding["deposit"]!
            var details = operation["details"] as! [String: [String: Any]]
            var payload = details["deposit"]!["_0"] as! [String: Any]
            payload["settlementLane"] = "a field from a build this one does not know"
            details["deposit"]!["_0"] = payload
            operation["details"] = details
            funding["deposit"] = operation
            document["funding"] = funding
        }
        let funding = try await journal.allFunding()
        let trading = try await journal.allPending()
        XCTAssertEqual(funding, [deposit])
        XCTAssertEqual(trading.map(\.operationId), ["trade"])
    }

    /// Earlier builds recorded a deposit from its first step, under stages this one no longer
    /// writes. Unread, one of them would set every funding record aside.
    func testDepositStagesOfAnEarlierBuildStillLoad() async throws {
        let journal = makeJournal()
        let written = ["prepared": "preparing", "approved": "approvalPending", "signed": "gatewaySigned", "sent": "sourceUnknown"]
        for operationId in written.keys {
            _ = try await journal.saveFundingIfAbsent(makeDeposit(operationId: operationId))
        }
        try rewriteDocument { document in
            var funding = document["funding"] as! [String: [String: Any]]
            for (operationId, stage) in written {
                var details = funding[operationId]!["details"] as! [String: [String: Any]]
                var payload = details["deposit"]!["_0"] as! [String: Any]
                payload["stage"] = stage
                details["deposit"]!["_0"] = payload
                funding[operationId]!["details"] = details
            }
            document["funding"] = funding
        }

        let read = try await journal.allFunding()
        let stages = Dictionary(uniqueKeysWithValues: read.map { ($0.operationId, $0.deposit?.stage) })
        XCTAssertEqual(stages, ["prepared": .preparing, "approved": .approvalPending, "signed": .gatewaySigned, "sent": .sourceUnknown])
        let next = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "next"))
        XCTAssertTrue(next.inserted)
    }

    func testUnchangedFundingDoesNotRewriteTheJournalOrAdvanceRevision() async throws {
        let journal = makeJournal()
        let saved = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "deposit")).operation
        let file = try journalFileURL()
        let contents = try Data(contentsOf: file)
        let oldDate = Date(timeIntervalSince1970: 100)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        let updated = try await journal.updateFunding(operationId: "deposit", expectedRevision: saved.revision) { _ in }
        XCTAssertEqual(updated, saved)
        XCTAssertEqual(try Data(contentsOf: file), contents)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(attributes[.modificationDate] as? Date, oldDate)
    }

    func testStaleRevisionCannotRollBackANewerStage() async throws {
        let journal = makeJournal()
        let saved = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "deposit")).operation

        let advanced = try await journal.updateFunding(
            operationId: "deposit",
            expectedRevision: saved.revision
        ) { operation in
            operation.mutateDeposit { $0.stage = .registeredPending }
        }

        do {
            _ = try await journal.updateFunding(operationId: "deposit", expectedRevision: saved.revision) { operation in
                operation.mutateDeposit { $0.stage = .credited }
            }
            XCTFail("a stale writer must not overwrite a newer stage")
        } catch {
            XCTAssertEqual(
                error as? PerpsPendingJournalError,
                .revisionMismatch(operationId: "deposit", expected: saved.revision, actual: advanced.revision)
            )
        }

        let stored = try await journal.funding(operationId: "deposit")
        XCTAssertEqual(stored?.deposit?.stage, .registeredPending)
        XCTAssertEqual(stored?.revision, advanced.revision)
    }

    func testTransformCannotTurnAnOperationIntoAnother() async throws {
        let journal = makeJournal()
        let saved = try await journal.saveFundingIfAbsent(makeDeposit(operationId: "deposit")).operation

        do {
            _ = try await journal.updateFunding(operationId: "deposit", expectedRevision: saved.revision) { operation in
                operation.details = .withdraw(Self.makeWithdrawDetails(stage: .reviewed))
            }
            XCTFail("an operation's kind must stay what it was")
        } catch {
            XCTAssertEqual(error as? PerpsPendingJournalError, .identityChanged("deposit"))
        }

        let stored = try await journal.funding(operationId: "deposit")
        XCTAssertEqual(stored, saved)
    }

    func testCleanupKeepsUnresolvedPaymentsAndDropsResolvedOnes() async throws {
        let journal = makeJournal()
        let aDayAndAnHourAgo = Self.nowMillis - 25 * 60 * 60 * 1000
        for operation in [
            makeDeposit(operationId: "credited", stage: .credited, updatedAtMillis: aDayAndAnHourAgo),
            makeDeposit(operationId: "unknown", stage: .registrationPending, updatedAtMillis: aDayAndAnHourAgo),
            makeDeposit(operationId: "unconfirmed", stage: .unconfirmed, updatedAtMillis: aDayAndAnHourAgo),
            makeDeposit(operationId: "draft", stage: .draft, updatedAtMillis: aDayAndAnHourAgo),
            makeWithdraw(operationId: "sending", stage: .sending, updatedAtMillis: aDayAndAnHourAgo),
            makeWithdraw(operationId: "fresh-review", stage: .reviewed),
        ] {
            _ = try await journal.saveFundingIfAbsent(operation)
        }

        let snapshot = try await journal.cleanupPending()

        let remaining = try Set(await makeJournal().allFunding().map(\.operationId))
        XCTAssertEqual(Set(snapshot.funding.map(\.operationId)), remaining)
        XCTAssertEqual(remaining, Set(["unknown", "unconfirmed", "sending", "fresh-review"]))
    }

    func testAStalledDepositIsKeptAsEvidenceButNotForever() async throws {
        let journal = makeJournal()
        let day: Int64 = 24 * 60 * 60 * 1000
        for operation in [
            makeDeposit(operationId: "recent", stage: .unconfirmed, updatedAtMillis: Self.nowMillis - 29 * day),
            makeDeposit(operationId: "expired", stage: .unconfirmed, updatedAtMillis: Self.nowMillis - 31 * day),
            makeDeposit(operationId: "owed", stage: .registrationPending, updatedAtMillis: Self.nowMillis - 400 * day),
            makeWithdraw(operationId: "unknown", stage: .unknown, updatedAtMillis: Self.nowMillis - 400 * day),
        ] {
            _ = try await journal.saveFundingIfAbsent(operation)
        }

        let snapshot = try await journal.cleanupPending()

        let remaining = try Set(await makeJournal().allFunding().map(\.operationId))
        XCTAssertEqual(Set(snapshot.funding.map(\.operationId)), remaining)
        XCTAssertEqual(remaining, Set(["recent", "owed", "unknown"]))
    }

    func testRemovingAnOperationRejectsAStaleRevision() async throws {
        let journal = makeJournal()
        let saved = try await journal.saveFundingIfAbsent(makeWithdraw(operationId: "withdraw")).operation
        _ = try await journal.updateFunding(operationId: "withdraw", expectedRevision: saved.revision) { operation in
            operation.mutateWithdraw { $0.stage = .accepted }
        }

        do {
            try await journal.removeFunding(operationId: "withdraw", expectedRevision: saved.revision)
            XCTFail("a stale writer must not drop a record it has not seen")
        } catch {}
        let afterStaleRemoval = try await journal.funding(operationId: "withdraw")
        XCTAssertEqual(afterStaleRemoval?.withdraw?.stage, .accepted)

        try await journal.removeFunding(operationId: "withdraw", expectedRevision: saved.revision + 1)
        let stored = try await journal.funding(operationId: "withdraw")
        XCTAssertNil(stored)
    }

    func testAnUnresolvedWithdrawAttemptSurvivesARestart() async throws {
        let journal = makeJournal()
        let saved = try await journal.saveFundingIfAbsent(makeWithdraw(operationId: "withdraw")).operation
        let step = PerpsPendingSignedStep(
            stepId: "withdraw",
            attemptId: "attempt-1",
            nonce: 7,
            transactionExpiryUnixMs: 99,
            txType: 14,
            txInfo: "payload",
            txHash: "hash",
            state: .sending
        )
        _ = try await journal.updateFunding(operationId: "withdraw", expectedRevision: saved.revision) { operation in
            operation.mutateWithdraw {
                $0.steps.append(step)
                $0.stage = .sending
            }
        }

        let restored = try await makeJournal().funding(operationId: "withdraw")

        XCTAssertEqual(restored?.withdraw?.steps, [step])
        XCTAssertEqual(restored?.withdraw?.unresolvedStep, step)
        XCTAssertEqual(restored?.withdraw?.stage, .sending)
        XCTAssertTrue(restored?.isUnresolved == true)
    }

    func testWithdrawalNonceBoundaryForAnotherSubmission() {
        var withdraw = Self.makeWithdrawDetails(stage: .unknown)
        XCTAssertFalse(withdraw.noncePassed(accountIndex: 42, nextNonce: 8))
        withdraw.steps = [.init(
            stepId: "step", attemptId: "attempt", nonce: 7, transactionExpiryUnixMs: 99,
            txType: 13, txInfo: "payload", txHash: "hash", state: .unknown
        )]
        XCTAssertFalse(withdraw.noncePassed(accountIndex: 43, nextNonce: 8))
        XCTAssertFalse(withdraw.noncePassed(accountIndex: 42, nextNonce: 7))
        XCTAssertTrue(withdraw.noncePassed(accountIndex: 42, nextNonce: 8))

        for stage in [PerpsWithdrawStage.signed, .sending, .unknown] {
            withdraw.stage = stage
            XCTAssertTrue(withdraw.blocksNewWithdrawal)
        }
        for stage in [PerpsWithdrawStage.accepted, .awaitingL1, .settled, .unconfirmed, .rejected] {
            withdraw.stage = stage
            XCTAssertFalse(withdraw.blocksNewWithdrawal)
        }
    }
}

private extension PerpsPendingFundingOperation {
    mutating func mutateDeposit(_ body: (inout PerpsPendingDeposit) -> Void) {
        guard var deposit else { return }
        body(&deposit)
        details = .deposit(deposit)
    }

    mutating func mutateWithdraw(_ body: (inout PerpsPendingWithdraw) -> Void) {
        guard var withdraw else { return }
        body(&withdraw)
        details = .withdraw(withdraw)
    }
}

private extension PerpsPendingJournalFundingTests {
    static var nowMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func makeJournal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    func makeTradingPending() -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: "trade",
            createdAtMillis: 1,
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: .open(limitPrice: nil)
        )
    }

    func makeDeposit(
        operationId: String,
        stage: PerpsDepositStage = .registrationPending,
        sourceAmountUnits: String = "25000000",
        updatedAtMillis: Int64? = nil
    ) -> PerpsPendingFundingOperation {
        makeOperation(
            operationId: operationId,
            updatedAtMillis: updatedAtMillis,
            details: .deposit(PerpsPendingDeposit(
                stage: stage,
                route: .directGateway,
                beneficiary: "0xabc",
                sourceAsset: Self.usdcEthereum,
                sourceAmountUnits: sourceAmountUnits,
                targetAsset: Self.usdcEthereum
            ))
        )
    }

    func makeWithdraw(
        operationId: String,
        stage: PerpsWithdrawStage = .reviewed,
        updatedAtMillis: Int64? = nil
    ) -> PerpsPendingFundingOperation {
        makeOperation(
            operationId: operationId,
            updatedAtMillis: updatedAtMillis,
            details: .withdraw(Self.makeWithdrawDetails(stage: stage))
        )
    }

    static func makeWithdrawDetails(stage: PerpsWithdrawStage) -> PerpsPendingWithdraw {
        PerpsPendingWithdraw(
            stage: stage,
            accountIndex: 42,
            apiKeyIndex: 1,
            chainId: 304,
            assetIndex: 0,
            routeType: 0,
            amountUnits: "25000000"
        )
    }

    static var usdcEthereum: PerpsFundingAsset {
        PerpsFundingAsset(
            assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            symbol: "USDC",
            decimals: 6
        )
    }

    func makeOperation(
        operationId: String,
        updatedAtMillis: Int64?,
        details: PerpsPendingFundingDetails
    ) -> PerpsPendingFundingOperation {
        PerpsPendingFundingOperation(
            operationId: operationId,
            walletId: "wallet",
            walletIdentity: "identity",
            environment: "test",
            createdAtMillis: updatedAtMillis ?? Self.nowMillis,
            updatedAtMillis: updatedAtMillis,
            details: details
        )
    }

    func rewriteDocument(_ body: (inout [String: Any]) -> Void) throws {
        let url = journalFileURL()
        guard var document = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        body(&document)
        try JSONSerialization.data(withJSONObject: document).write(to: url)
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
