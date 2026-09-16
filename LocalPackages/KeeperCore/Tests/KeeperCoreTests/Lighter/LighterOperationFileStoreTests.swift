import ChainKit
import Foundation
@testable import KeeperCore
import XCTest

final class LighterOperationFileStoreTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LighterOperationFileStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testConcurrentStoresDoNotLoseOperations() async throws {
        let stores = [makeStore(), makeStore()]
        let operationIds = (0 ..< 40).map { "operation-\($0)" }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, operationId) in operationIds.enumerated() {
                group.addTask {
                    try await self.save(
                        self.makeOperation(operationId: operationId, createdAtMillis: Int64(index)),
                        to: stores[index % stores.count]
                    )
                }
            }
            try await group.waitForAll()
        }

        let loaded = try await load(from: stores[0])
        XCTAssertEqual(Set(loaded.map(\.operationId)), Set(operationIds))
    }

    func testOperationAndPendingActionSurviveStoreRecreation() async throws {
        let originalStore = makeStore()
        let operation = makeOperation(operationId: "restart")
        let pending = makePending(operationId: operation.operationId, createdAtMillis: 123)
        try await save(operation, to: originalStore)
        _ = try await originalStore.savePendingIfAbsent(pending)

        let restoredStore = makeStore()
        let restoredOperations = try await load(from: restoredStore)
        let restoredPending = try await restoredStore.pending(operationId: operation.operationId)

        XCTAssertEqual(restoredOperations.count, 1)
        XCTAssertEqual(
            try LighterOperationCodec.shared.encode(operation: restoredOperations[0]),
            try LighterOperationCodec.shared.encode(operation: operation)
        )
        XCTAssertEqual(restoredPending, pending)
    }

    func testLoadIsolatesAccountAndApiKeyLanes() async throws {
        let store = makeStore()
        try await save(makeOperation(operationId: "primary"), to: store)
        try await save(
            makeOperation(operationId: "other-account", accountIndex: 43),
            to: store
        )
        try await save(
            makeOperation(operationId: "other-key", apiKeyIndex: 4),
            to: store
        )

        let primary = try await load(from: store).map(\.operationId)
        let otherAccount = try await load(from: store, accountIndex: 43, apiKeyIndex: 3).map(\.operationId)
        let otherKey = try await load(from: store, accountIndex: 42, apiKeyIndex: 4).map(\.operationId)

        XCTAssertEqual(primary, ["primary"])
        XCTAssertEqual(otherAccount, ["other-account"])
        XCTAssertEqual(otherKey, ["other-key"])
    }

    func testCorruptDocumentFailsLoudly() async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: operationFileURL())

        do {
            _ = try await load(from: makeStore())
            XCTFail("corrupt operation journal must not be treated as empty")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testUnsupportedDocumentVersionFailsLoudly() async throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(#"{"version":2,"operations":{},"pending":{}}"#.utf8).write(to: operationFileURL())

        do {
            _ = try await load(from: makeStore())
            XCTFail("unsupported operation journal version must not be treated as empty")
        } catch {
            XCTAssertFalse(error is DecodingError)
        }
    }

    func testPruningRetainsEveryUnresolvedAndNewestTerminalOperations() async throws {
        let store = makeStore()
        for index in 0 ..< 105 {
            try await save(
                makeOperation(
                    operationId: "terminal-\(index)",
                    state: .succeeded,
                    stepState: .succeeded,
                    createdAtMillis: Int64(index),
                    updatedAtMillis: Int64(index)
                ),
                to: store
            )
        }
        let unresolved = [
            makeOperation(operationId: "signed", createdAtMillis: 200),
            makeOperation(
                operationId: "unknown",
                state: .outcomeUnknown,
                stepState: .outcomeUnknown,
                createdAtMillis: 201
            ),
        ]
        for operation in unresolved {
            try await save(operation, to: store)
        }

        let loaded = try await load(from: store)
        let terminal = loaded.filter(\.isTerminal)
        XCTAssertEqual(terminal.count, 100)
        XCTAssertEqual(Set(loaded.filter { !$0.isTerminal }.map(\.operationId)), ["signed", "unknown"])
        XCTAssertFalse(terminal.contains { $0.operationId == "terminal-0" })
        XCTAssertTrue(terminal.contains { $0.operationId == "terminal-104" })
    }

    func testCleanupKeepsOnlyRecoverableAndFreshOrphanPendingActions() async throws {
        let store = makeStore()
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        try await save(makeOperation(operationId: "unresolved"), to: store)
        try await save(
            makeOperation(
                operationId: "terminal",
                state: .succeeded,
                stepState: .succeeded
            ),
            to: store
        )

        for pending in [
            makePending(operationId: "unresolved", createdAtMillis: nowMillis - 120_000),
            makePending(operationId: "terminal", createdAtMillis: nowMillis),
            makePending(operationId: "old-orphan", createdAtMillis: nowMillis - 120_000),
            makePending(operationId: "fresh-orphan", createdAtMillis: nowMillis),
        ] {
            _ = try await store.savePendingIfAbsent(pending)
        }

        try await store.cleanupPending()

        let unresolved = try await store.pending(operationId: "unresolved")
        let terminal = try await store.pending(operationId: "terminal")
        let oldOrphan = try await store.pending(operationId: "old-orphan")
        let freshOrphan = try await store.pending(operationId: "fresh-orphan")
        XCTAssertNotNil(unresolved)
        XCTAssertNil(terminal)
        XCTAssertNil(oldOrphan)
        XCTAssertNotNil(freshOrphan)
    }

    func testPendingLimitOrderChangeRoundTripsThroughTheDurableJournal() async throws {
        let store = makeStore()
        let pending = PerpsPendingTradingAction(
            operationId: "modify-limit",
            createdAtMillis: 123,
            kind: .limitOrderChange,
            walletId: "wallet",
            isTestnet: true,
            marketId: 1,
            side: .long,
            limitOrderChange: PerpsPendingLimitOrderChange(
                orderIndex: 77,
                kind: .modify,
                limitPrice: 67250.12
            )
        )

        _ = try await store.savePendingIfAbsent(pending)
        let restored = try await store.pending(operationId: pending.operationId)

        XCTAssertEqual(restored, pending)
    }
}

private extension LighterOperationFileStoreTests {
    func makeStore() -> LighterOperationFileStore {
        LighterOperationFileStore(
            walletId: "wallet",
            environment: "test",
            directoryURL: directoryURL
        )
    }

    func makeOperation(
        operationId: String,
        accountIndex: Int64 = 42,
        apiKeyIndex: Int32 = 3,
        state: LighterOperationState = .signed_,
        stepState: LighterOperationStepState = .signed_,
        createdAtMillis: Int64 = 1,
        updatedAtMillis: Int64? = nil
    ) -> LighterOperation {
        let step = LighterOperationStep(
            index: 0,
            txType: 14,
            txInfo: "{\"Nonce\":1}",
            txHash: "hash-\(operationId)",
            nonce: 1,
            clientOrderIndexes: [],
            state: stepState,
            venueStatus: nil,
            failure: nil
        )
        return LighterOperation(
            operationId: operationId,
            accountIndex: accountIndex,
            apiKeyIndex: apiKeyIndex,
            state: state,
            steps: [step],
            createdAtMillis: createdAtMillis,
            updatedAtMillis: updatedAtMillis ?? createdAtMillis,
            nonceRetryCount: 0,
            failure: nil
        )
    }

    func makePending(
        operationId: String,
        createdAtMillis: Int64
    ) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: operationId,
            createdAtMillis: createdAtMillis,
            kind: .open,
            walletId: "wallet",
            isTestnet: true,
            marketId: 1,
            side: .long
        )
    }

    func save(_ operation: LighterOperation, to store: LighterOperationFileStore) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(operation: operation) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func load(
        from store: LighterOperationFileStore,
        accountIndex: Int64 = 42,
        apiKeyIndex: Int32 = 3
    ) async throws -> [LighterOperation] {
        try await withCheckedThrowingContinuation { continuation in
            store.load(accountIndex: accountIndex, apiKeyIndex: apiKeyIndex) { operations, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: operations ?? [])
                }
            }
        }
    }

    func operationFileURL() -> URL {
        let scope = Data("wallet/test".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directoryURL.appendingPathComponent("\(scope).json")
    }
}
