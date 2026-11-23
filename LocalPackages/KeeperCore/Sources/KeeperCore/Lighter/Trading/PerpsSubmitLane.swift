import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

actor PerpsSubmitLane {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let api: PerpsAPI
    private let apiKeyIndex: Int32
    private var held = false
    private var waiting = [Waiter]()
    private var cursor: Int64?
    private var acceptedNonce: Int64?
    /// Sends finished through this lane, so a read can tell whether one ended after it began.
    private var sends = 0
    private var preReads: [Int64: (sends: Int, read: Task<Components.Schemas.TradingScreen, Error>)] = [:]

    init(api: PerpsAPI, apiKeyIndex: Int32) {
        self.api = api
        self.apiKeyIndex = apiKeyIndex
    }

    func run<T>(
        isolation _: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async throws -> T {
        guard await acquire() else { throw CancellationError() }
        do {
            try Task.checkCancellation()
            let value = try await body()
            await release()
            return value
        } catch {
            await release()
            throw error
        }
    }

    func nextNonce(walletId: String) async throws -> Int64 {
        if let cursor {
            return try issue(after: cursor)
        }
        let remote = try await venueNonce(walletId: walletId)
        // A suspended actor call may interleave another initializer; allocate
        // after its cursor rather than returning a duplicate nonce.
        if let cursor {
            return try issue(after: cursor)
        }
        let first = max(remote, (acceptedNonce ?? remote - 1) + 1)
        cursor = first
        return first
    }

    /// Reads the venue nonce ahead of an operation's first signing and takes it as the cursor. A nonce
    /// this lane issued but never got accepted does not hold the cursor up; one the venue accepted does,
    /// in case the venue has not counted it yet. A read that fails drops the cursor, so the signing
    /// reads the venue again instead of trusting it.
    func catchUpNonce(walletId: String) async {
        let cursorBeforeRead = cursor
        guard let remote = try? await venueNonce(walletId: walletId), remote >= 0 else {
            if cursor == cursorBeforeRead { cursor = nil }
            return
        }
        let issuedDuringRead = cursor == cursorBeforeRead ? nil : cursor
        cursor = [remote - 1, acceptedNonce, issuedDuringRead].compactMap { $0 }.max()
    }

    /// A trading screen read started when the user begins to confirm, for the submit to plan on.
    func preRead(marketId: Int64, read: @escaping @Sendable () async throws -> Components.Schemas.TradingScreen) {
        preReads[marketId] = (sends, Task { try await read() })
    }

    func dropPreRead(marketId: Int64) {
        preReads[marketId] = nil
    }

    /// Nil when there is none, or when something was sent after it began: then it may miss
    /// what that send changed.
    func takePreRead(marketId: Int64) -> Task<Components.Schemas.TradingScreen, Error>? {
        guard let entry = preReads.removeValue(forKey: marketId), entry.sends == sends else { return nil }
        return entry.read
    }

    func resyncNonce(walletId: String) async throws {
        let cursorBeforeRead = cursor
        let remote: Int64
        do {
            remote = try await venueNonce(walletId: walletId)
        } catch {
            // A failed refresh must not leave a stale cursor behind.
            if cursor == cursorBeforeRead { cursor = nil }
            throw error
        }
        if let issuedDuringRead = cursor, issuedDuringRead != cursorBeforeRead {
            cursor = max(issuedDuringRead, remote - 1, acceptedNonce ?? remote - 1)
        } else {
            // `next` returns the anchor itself, so keep the previous value here.
            cursor = max(remote - 1, acceptedNonce ?? remote - 1)
        }
    }

    func reuseNonce(_ nonce: Int64) throws {
        guard nonce >= 0 else {
            throw PerpsTradingError.validation("nonce to reuse is negative")
        }
        cursor = nonce - 1
    }

    func returnUnconsumedNonce(_ nonce: Int64) {
        guard cursor == nonce else { return }
        cursor = nonce - 1
    }

    func forgetNonce() {
        cursor = nil
    }

    func advanceNonce(to nextNonce: Int64) throws {
        guard nextNonce >= 0 else {
            throw PerpsTradingError.validation("nonce response is negative")
        }
        let anchor = nextNonce - 1
        cursor = max(cursor ?? anchor, anchor)
    }

    /// `operationId` names the funding operation the transaction carries out, for its pushes to name it back.
    func send(walletId: String, txType: Int32, txInfo: String, txHash: String, nonce: Int64? = nil, operationId: String? = nil) async throws {
        defer { sends += 1 }
        try await post(walletId: walletId, txType: txType, txInfo: txInfo, txHash: txHash, operationId: operationId)
        if let nonce {
            acceptedNonce = max(acceptedNonce ?? nonce, nonce)
        }
    }

    private func post(walletId: String, txType: Int32, txInfo: String, txHash: String, operationId: String?) async throws {
        return try await PerpsOperationLog.step("l2_send", source: "backend", fields: ["wallet_id": walletId, "api_key_index": String(apiKeyIndex), "tx_type": String(txType), "l2_tx_hash": txHash]) {
            let response = try await api.sendTransactions(
                walletId: walletId,
                operationId: operationId,
                transactions: [.init(tx_type: txType, tx_info: txInfo)]
            )
            PerpsOperationLog.event("l2_send_response", outcome: "received", source: "backend", fields: ["response_transactions": response.transactions.map { "\($0.tx_type):\($0.tx_hash)" }.joined(separator: ",")])
            let responseHash = PerpsExecutionRelay.normalizedHash(response.transactions.first?.tx_hash ?? "")
            let expectedHash = PerpsExecutionRelay.normalizedHash(txHash)
            guard response.transactions.count == 1,
                  response.transactions[0].tx_type == txType,
                  !responseHash.isEmpty,
                  !expectedHash.isEmpty,
                  responseHash == expectedHash
            else {
                throw PerpsTradingError.protocolFailure("send response does not match the submitted transaction")
            }
        }
    }
}

private extension PerpsSubmitLane {
    func acquire() async -> Bool {
        guard held else {
            held = true
            return true
        }
        let id = UUID()
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    waiting.append(Waiter(id: id, continuation: continuation))
                }
            } onCancel: {
                Task { await self.cancel(id: id) }
            }
            return true
        } catch {
            return false
        }
    }

    func cancel(id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    func release() {
        guard !waiting.isEmpty else {
            held = false
            return
        }
        waiting.removeFirst().continuation.resume()
    }

    func venueNonce(walletId: String) async throws -> Int64 {
        return try await PerpsOperationLog.step("nonce", source: "backend", fields: ["wallet_id": walletId, "api_key_index": String(apiKeyIndex)]) {
            let remote = try await api.nextNonce(walletId: walletId, apiKeyIndex: Int(apiKeyIndex)).nonce
            guard remote >= 0 else {
                throw PerpsTradingError.validation("nonce response is negative")
            }
            return remote
        }
    }

    func issue(after cursor: Int64) throws -> Int64 {
        let (next, overflow) = cursor.addingReportingOverflow(1)
        guard !overflow else {
            throw PerpsTradingError.validation("nonce overflow")
        }
        self.cursor = next
        return next
    }
}

/// One lane per account for the whole process: a wallet scope is rebuilt per screen,
/// and a second lane would hand out a nonce the first one has already used.
actor PerpsSubmitLanes {
    private struct Key: Hashable {
        let environment: String
        let accountIndex: Int64
        let apiKeyIndex: Int32
    }

    private let api: PerpsAPI
    private var lanes = [Key: PerpsSubmitLane]()

    init(api: PerpsAPI) {
        self.api = api
    }

    func lane(for session: PerpsAccountSession) -> PerpsSubmitLane {
        let key = Key(
            environment: PerpsEnvironment.venue,
            accountIndex: session.accountIndex,
            apiKeyIndex: session.apiKeyIndex
        )
        if let lane = lanes[key] { return lane }
        let lane = PerpsSubmitLane(api: api, apiKeyIndex: session.apiKeyIndex)
        lanes[key] = lane
        return lane
    }
}
