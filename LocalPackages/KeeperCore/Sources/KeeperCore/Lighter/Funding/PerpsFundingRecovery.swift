import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI

actor PerpsFundingRecovery {
    private let walletId: String?
    private let walletIdentity: String
    private let environment: String
    private let journal: PerpsPendingJournal
    private let api: PerpsAPI
    private let delivery: (any PerpsDepositDelivery)?
    private(set) var heldDeposits = Set<String>()
    private let registrar: PerpsDepositRegistrar
    private let sleep: @Sendable (UInt64) async throws -> Void
    private let executionTime: @Sendable (String) async throws -> Int64?

    private var state: PerpsFundingState = .unresolved
    private var observers: [UUID: AsyncStream<PerpsFundingState>.Continuation] = [:]
    private var enabledObservers: Set<UUID> = []
    private var refusedRevisions: [String: Int] = [:]
    private var lastWithdrawPoll = [String: Date]()
    private var withdrawalExecutionTimes = [String: Int64]()
    private var heldWithdrawals = Set<String>()
    private var drivenOperationId: String?
    private var drivenOperationWaiters = [CheckedContinuation<Void, Never>]()
    private var refreshRequested = false
    private var task: Task<Void, Never>?
    private var sleepTask: Task<Void, Error>?

    init(
        walletId: String?,
        walletIdentity: String,
        environment: String,
        journal: PerpsPendingJournal,
        api: PerpsAPI,
        delivery: (any PerpsDepositDelivery)? = nil,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        executionTime: @escaping @Sendable (String) async throws -> Int64? = PerpsFundingRecovery.lighterExecutionTime
    ) {
        self.walletId = walletId
        self.walletIdentity = walletIdentity
        self.environment = environment
        self.journal = journal
        self.api = api
        self.delivery = delivery
        registrar = PerpsDepositRegistrar(api: api, journal: journal)
        self.sleep = sleep
        self.executionTime = executionTime
    }

    /// Returns once no pass drives the operation: one already sending or registering it
    /// finishes first, so the payment starts from what that pass left in the journal.
    func holdDeposit(_ operationId: String) async {
        heldDeposits.insert(operationId)
        guard drivenOperationId == operationId else { return }
        await withCheckedContinuation { drivenOperationWaiters.append($0) }
    }

    func releaseDeposit(_ operationId: String) {
        heldDeposits.remove(operationId)
        refresh()
    }

    func updates(for observerId: UUID) -> AsyncStream<PerpsFundingState> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            observers[observerId] = continuation
            continuation.yield(state)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(observerId) }
            }
        }
    }

    func setEnabled(_ enabled: Bool, for observerId: UUID) {
        guard observers[observerId] != nil else { return }
        if enabled {
            guard enabledObservers.insert(observerId).inserted else { return }
            if enabledObservers.count == 1 { refresh() }
        } else {
            enabledObservers.remove(observerId)
            stopIfUnused()
        }
    }

    func removeObserver(_ observerId: UUID) {
        let continuation = observers.removeValue(forKey: observerId)
        enabledObservers.remove(observerId)
        stopIfUnused()
        continuation?.finish()
    }

    /// Wakes the worker and lets refused bodies be tried again. A pass ends once nothing is
    /// left to poll and the journal has no change signal of its own, so whoever persists a
    /// funding operation or moves its stage forward calls this afterwards; without it the
    /// operation waits for the next time the flow is opened.
    func refresh() {
        refusedRevisions.removeAll()
        lastWithdrawPoll.removeAll()
        refreshRequested = true
        sleepTask?.cancel()
        startIfNeeded()
    }

    func holdWithdrawal(_ operationId: String) {
        heldWithdrawals.insert(operationId)
    }

    func releaseWithdrawal(_ operationId: String) {
        heldWithdrawals.remove(operationId)
        refresh()
    }

    /// Past this, a withdrawal nobody can confirm is kept as evidence and no longer polled.
    static let verdictWindowMillis: Int64 = 3 * 60 * 60 * 1000
    /// A withdrawal waits on the venue and on another chain; asking more often gains nothing.
    static let withdrawPollNanoseconds: UInt64 = 30_000_000_000
    private static let withdrawalPageLimit = 5

    static func pollDelayNanoseconds(afterFailures failures: Int) -> UInt64 {
        min(5_000_000_000 << UInt64(min(max(failures, 0), 4)), 30_000_000_000)
    }

    private func startIfNeeded() {
        guard task == nil, !enabledObservers.isEmpty else { return }
        task = Task { await run() }
    }

    private func stopIfUnused() {
        guard enabledObservers.isEmpty else { return }
        refreshRequested = false
        sleepTask?.cancel()
        task?.cancel()
        // Keep ownership until the cancelled request returns, even if transport
        // ignores cancellation. A resumed observer must not start a second worker.
    }

    private func run() async {
        defer {
            task = nil
            sleepTask = nil
            if refreshRequested { startIfNeeded() }
        }
        var failures = 0
        while !Task.isCancelled, !enabledObservers.isEmpty {
            refreshRequested = false
            let result = await recoverPass()
            guard !Task.isCancelled else { return }
            if refreshRequested { continue }
            guard result.shouldPoll else { return }
            failures = result.failed ? min(failures + 1, 4) : 0
            let delay = result.onlyWithdrawals
                ? Self.withdrawPollNanoseconds
                : Self.pollDelayNanoseconds(afterFailures: failures)
            let sleeper = Task { [sleep] in try await sleep(delay) }
            sleepTask = sleeper
            try? await sleeper.value
            sleepTask = nil
        }
    }

    private func recoverPass() async -> (shouldPoll: Bool, failed: Bool, onlyWithdrawals: Bool) {
        var operations: [PerpsPendingFundingOperation]
        let fundingIntact: Bool
        do {
            let cleaned = try await journal.cleanupPending()
            fundingIntact = cleaned.fundingIntact
            operations = cleaned.funding.filter {
                $0.belongs(walletId: walletId, walletIdentity: walletIdentity, environment: environment)
            }.sorted {
                ($0.createdAtMillis, $0.operationId) < ($1.createdAtMillis, $1.operationId)
            }
            try Task.checkCancellation()
        } catch {
            guard !Task.isCancelled else { return (false, false, false) }
            publish(.unavailable(lastKnown: state.operations))
            return (true, true, false)
        }
        // Records the journal had to set aside make whatever it still holds a partial list:
        // it is followed, but not presented as the whole of this wallet's funding.
        let present: ([PerpsPendingFundingOperation]) -> PerpsFundingState = {
            fundingIntact ? .loaded($0) : .unavailable(lastKnown: $0)
        }
        publish(present(operations))
        refusedRevisions = refusedRevisions.filter { id, revision in
            operations.contains { $0.operationId == id && $0.revision == revision }
        }
        var shouldPoll = false
        var pollsDeposits = false
        var failed = false
        for index in operations.indices {
            // A released hold or a new operation makes this pass's snapshot stale.
            guard !Task.isCancelled, !refreshRequested else { break }
            let operation = operations[index]
            guard !heldDeposits.contains(operation.operationId) else { continue }
            guard refusedRevisions[operation.operationId] != operation.revision else { continue }
            drivenOperationId = operation.operationId
            defer { finishDriving() }
            do {
                let updated: PerpsPendingFundingOperation
                if operation.withdraw != nil {
                    let result = try await refreshWithdraw(operation)
                    operations[index] = result.operation
                    publish(present(operations))
                    shouldPoll = shouldPoll || result.shouldPoll
                    continue
                }
                switch operation.deposit?.stage {
                case .sourcePending:
                    guard let delivery, let deposit = operation.deposit, let transmission = deposit.transmission,
                          let chain = PerpsDepositService.fundingChain(assetId: deposit.sourceAsset.assetId)
                    else { continue }
                    if transmission.expiresAt <= Date() {
                        let mainId = try transmission.operation.parsed().payloads.last?.id
                        let main = transmission.steps.last { $0.payloadId == mainId }
                        let expired = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { stored in
                            guard var deposit = stored.deposit else { return }
                            deposit.stage = main?.broadcastAttempted == true ? (deposit.registration == nil ? .needsAuthorization : .registrationPending) : .failed
                            stored.details = .deposit(deposit)
                        }
                        // A main payload that may be on chain still owes the backend its registration.
                        if expired.deposit?.stage == .registrationPending {
                            updated = try await registrar.register(operation: expired)
                        } else {
                            updated = expired
                        }
                    } else {
                        try await registrar.recordBeforeBroadcast(operation: operation)
                        try await delivery.broadcast(transmission, on: chain) { [journal] step in
                            _ = try await journal.persistDepositStep(step, operationId: operation.operationId)
                        }
                        updated = try await journal.funding(operationId: operation.operationId) ?? operation
                    }
                case .registrationPending:
                    if let deposit = operation.deposit,
                       let step = deposit.route == .crosschainSwap ? deposit.sourceStep : deposit.gatewayStep,
                       step.state != .accepted
                    {
                        guard let delivery, let chain = PerpsDepositService.fundingChain(assetId: deposit.sourceAsset.assetId) else { continue }
                        let expiresAt = deposit.route == .crosschainSwap ? deposit.quoteExpiresAtMillis.map { Date(timeIntervalSince1970: Double($0) / 1000) } : nil
                        do {
                            try await delivery.broadcastLegacy(step, on: chain, expiresAt: expiresAt)
                        } catch ChainKitOperationError.quoteExpired {
                            updated = try await registrar.register(operation: operation)
                            operations[index] = updated
                            publish(present(operations))
                            shouldPoll = updated.deposit?.stage == .registeredPending || shouldPoll
                            pollsDeposits = true
                            continue
                        }
                        _ = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { stored in
                            guard var deposit = stored.deposit else { return }
                            deposit.sourceStep?.state = .accepted
                            deposit.gatewayStep?.state = .accepted
                            stored.details = .deposit(deposit)
                        }
                        let current = try await journal.funding(operationId: operation.operationId) ?? operation
                        updated = try await registrar.register(operation: current)
                    } else {
                        updated = try await registrar.register(operation: operation)
                    }
                case .registeredPending:
                    updated = try await registrar.refresh(operation: operation)
                default:
                    continue
                }
                try Task.checkCancellation()
                operations[index] = updated
                publish(present(operations))
                if updated.deposit?.stage == .registeredPending || updated.deposit?.stage == .registrationPending {
                    shouldPoll = true
                    pollsDeposits = true
                }
            } catch {
                guard !Task.isCancelled else { break }
                if let withdraw = operation.withdraw {
                    Log.perps.w("Withdraw recovery failed op=\(operation.operationId) stage=\(withdraw.stage.rawValue)", error: error)
                }
                if Self.canRetry(error) {
                    shouldPoll = true
                    failed = true
                } else {
                    // Retry a rejected body only after explicit refresh/resume or a
                    // new journal revision, not on every poll of another deposit.
                    refusedRevisions[operation.operationId] = operation.revision
                }
            }
        }
        return (shouldPoll, failed, !pollsDeposits && !failed)
    }

    private func finishDriving() {
        drivenOperationId = nil
        let waiters = drivenOperationWaiters
        drivenOperationWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func refreshWithdraw(
        _ operation: PerpsPendingFundingOperation
    ) async throws -> (operation: PerpsPendingFundingOperation, shouldPoll: Bool) {
        guard let withdraw = operation.withdraw, !withdraw.stage.isOutcome else { return (operation, false) }
        if heldWithdrawals.contains(operation.operationId) { return (operation, true) }
        let now = Date()
        if let last = lastWithdrawPoll[operation.operationId], now.timeIntervalSince(last) < 30 {
            return (operation, true)
        }
        lastWithdrawPoll[operation.operationId] = now
        let nowMillis = Int64(now.timeIntervalSince1970 * 1000)
        let age = nowMillis - operation.updatedAtMillis
        let isPastVerdictWindow = nowMillis - operation.createdAtMillis >= Self.verdictWindowMillis
        switch withdraw.stage {
        case .signed, .sending, .unknown:
            if withdraw.stage != .unknown, age < 30000 { return (operation, true) }
            if let executionId = withdraw.executionId {
                if withdraw.stage != .signed, let status = try await relayVerdict(of: operation, executionId: executionId) {
                    return try await applyWithdrawStatus(status, to: operation)
                }
            } else if let item = try await directWithdrawal(of: operation, withdraw: withdraw) {
                return try await applyDirectWithdrawal(item, to: operation)
            }
            if age >= 30000, let step = withdraw.steps.last,
               step.transactionExpiryUnixMs > nowMillis,
               withdraw.quoteExpiresAtMillis.map({ $0 > nowMillis }) ?? true
            {
                let nextNonce = try? await api.nextNonce(walletId: operation.walletId, apiKeyIndex: Int(withdraw.apiKeyIndex))
                guard let nextNonce, withdraw.noncePassed(accountIndex: nextNonce.account_index, nextNonce: nextNonce.nonce) else {
                    return try await replayWithdraw(operation, step: step)
                }
                Log.perps.i("Withdraw nonce spent, not replaying op=\(operation.operationId) stepNonce=\(step.nonce) nextNonce=\(nextNonce.nonce)")
            }
            guard isPastVerdictWindow else { return (operation, true) }
            return try await markUnconfirmed(operation, reason: "l2_unverified")
        case .accepted:
            if let executionId = withdraw.executionId,
               let status = try await relayVerdict(of: operation, executionId: executionId)
            {
                return try await applyWithdrawStatus(status, to: operation)
            }
            guard isPastVerdictWindow else { return (operation, true) }
            return try await markUnconfirmed(operation, reason: "l1_unverified")
        case .awaitingL1:
            guard withdraw.executionId == nil else { return (operation, false) }
            if let item = try await directWithdrawal(of: operation, withdraw: withdraw) {
                if Self.verdict(of: item) != nil || withdraw.withdrawalId == nil {
                    return try await applyDirectWithdrawal(item, to: operation)
                }
            }
            guard isPastVerdictWindow else { return (operation, true) }
            return try await markUnconfirmed(operation, reason: "l1_unverified")
        case .reviewed, .settled, .unconfirmed, .rejected:
            return (operation, false)
        }
    }

    /// A terminal status, or `nil` while there is none — a 404 included: the relay may not
    /// have seen the transfer yet, and refusing the revision would stop the clock that ends it.
    private func relayVerdict(
        of operation: PerpsPendingFundingOperation,
        executionId: String
    ) async throws -> Components.Schemas.FundingStatus? {
        let status: Components.Schemas.FundingStatus
        do {
            status = try await api.getFundingStatus(walletId: operation.walletId, executionId: executionId)
        } catch let PerpsAPIError.badStatus(failure) where failure.httpStatus == 404 {
            return nil
        } catch PerpsAPIError.notFound {
            return nil
        }
        guard status.execution_id == executionId else {
            throw PerpsTradingError.protocolFailure("withdraw status belongs to another execution")
        }
        return [.success, .failure, .refund].contains(status.status) ? status : nil
    }

    private func applyWithdrawStatus(
        _ status: Components.Schemas.FundingStatus,
        to operation: PerpsPendingFundingOperation
    ) async throws -> (operation: PerpsPendingFundingOperation, shouldPoll: Bool) {
        switch status.status {
        case .pending, .unknown:
            return (operation, true)
        case .success, .failure, .refund:
            let updated = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { current in
                guard var value = current.withdraw else { return }
                value.stage = status.status == .success ? .settled : .rejected
                value.l1TxHash = status.tx_hashes?.first
                value.failureReason = status.status == .success ? nil : status.details ?? status.status.rawValue
                current.details = .withdraw(value)
            }
            return (updated, false)
        }
    }

    private func replayWithdraw(
        _ operation: PerpsPendingFundingOperation,
        step: PerpsPendingSignedStep
    ) async throws -> (operation: PerpsPendingFundingOperation, shouldPoll: Bool) {
        let sending = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { current in
            guard var value = current.withdraw else { return }
            value.stage = .sending
            value.steps[value.steps.count - 1] = step.withState(.sending)
            current.details = .withdraw(value)
        }
        do {
            let response = try await api.sendTransactions(
                walletId: operation.walletId,
                transactions: [.init(tx_type: step.txType, tx_info: step.txInfo)]
            )
            guard response.transactions.count == 1,
                  response.transactions[0].tx_type == step.txType,
                  !PerpsExecutionRelay.normalizedHash(step.txHash).isEmpty,
                  PerpsExecutionRelay.normalizedHash(response.transactions[0].tx_hash) == PerpsExecutionRelay.normalizedHash(step.txHash)
            else { throw PerpsWithdrawServiceError.sendUnknown }
            let accepted = try await journal.updateFunding(operationId: sending.operationId, expectedRevision: sending.revision) { current in
                guard var value = current.withdraw else { return }
                value.stage = value.executionId == nil ? .awaitingL1 : .accepted
                value.steps[value.steps.count - 1] = step.withState(.accepted)
                current.details = .withdraw(value)
            }
            return (accepted, true)
        } catch {
            let unknown = try await journal.updateFunding(operationId: sending.operationId, expectedRevision: sending.revision) { current in
                guard var value = current.withdraw else { return }
                value.stage = .unknown
                value.steps[value.steps.count - 1] = step.withState(.unknown)
                current.details = .withdraw(value)
            }
            return (unknown, true)
        }
    }

    /// The venue's history names its own id and L1 hash, so a fresh withdrawal is matched by
    /// its L2 execution time and amount. A known id or attempt hash takes precedence.
    private func directWithdrawal(
        of operation: PerpsPendingFundingOperation,
        withdraw: PerpsPendingWithdraw
    ) async throws -> Components.Schemas.ActivityItem? {
        guard let hash = withdraw.steps.last.map({ PerpsExecutionRelay.normalizedHash($0.txHash) }), !hash.isEmpty else {
            return nil
        }
        var matching = [Components.Schemas.ActivityItem]()
        var cursor: String?
        var executedAt = withdrawalExecutionTimes[hash]
        var needsExecutionTime = executedAt == nil && withdraw.withdrawalId == nil
        var searchedWindow = false
        for _ in 0 ..< Self.withdrawalPageLimit {
            let page = try await api.withdrawals(walletId: operation.walletId, cursor: cursor)
            try Task.checkCancellation()
            let items = page.items ?? []
            let referenced = items.filter { item in
                item._type == .withdrawal
                    && (withdraw.withdrawalId.map { item.id == $0 || item.tx_hash == $0 } == true
                        || [item.id, item.tx_hash].compactMap { $0.map(PerpsExecutionRelay.normalizedHash) }.contains(hash))
            }
            if !referenced.isEmpty { return referenced.count == 1 ? referenced.first : nil }
            if needsExecutionTime {
                needsExecutionTime = false
                // Lighter's public API failing only skips this match; it must not hold the
                // replay or the verdict window that follow.
                do {
                    executedAt = try await executionTime(hash)
                } catch {
                    try Task.checkCancellation()
                    Log.perps.w("Withdraw L2 execution time unavailable op=\(operation.operationId)", error: error)
                }
                try Task.checkCancellation()
                withdrawalExecutionTimes[hash] = executedAt
            }
            if let executedAt {
                matching += items.filter { item in
                    guard item._type == .withdrawal,
                          let timestamp = item.timestamp,
                          abs(timestamp.timeIntervalSince1970 * 1000 - Double(executedAt)) < 1000,
                          let amount = item.amount,
                          let units = try? PerpsFundingAmount.units(declaredAmount: amount, decimals: PerpsFundingAmount.usdcDecimals)
                    else { return false }
                    return units.description == withdraw.amountUnits
                }
            }
            let reachedAttempt = items.last?.timestamp.map {
                $0.timeIntervalSince1970 * 1000 < Double(executedAt.map { $0 - 1000 } ?? operation.createdAtMillis)
            } ?? true
            guard !reachedAttempt, let next = page.next_cursor, !next.isEmpty else {
                searchedWindow = true
                break
            }
            guard matching.count <= 1 else { break }
            cursor = next
        }
        return searchedWindow && matching.count == 1 ? matching.first : nil
    }

    /// The venue lists a withdrawal only once it has accepted it, so a listed attempt is past
    /// L2 even when this device never heard back.
    private func applyDirectWithdrawal(
        _ item: Components.Schemas.ActivityItem,
        to operation: PerpsPendingFundingOperation
    ) async throws -> (operation: PerpsPendingFundingOperation, shouldPoll: Bool) {
        let verdict = Self.verdict(of: item)
        let updated = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { current in
            guard var value = current.withdraw else { return }
            value.stage = verdict?.stage ?? .awaitingL1
            value.withdrawalId = item.id ?? item.tx_hash
            if let last = value.steps.indices.last {
                value.steps[last] = value.steps[last].withState(.accepted)
            }
            if let verdict {
                value.l1TxHash = item.tx_hash
                value.failureReason = verdict.stage == .settled ? nil : verdict.status
            }
            current.details = .withdraw(value)
        }
        return (updated, verdict == nil)
    }

    private static func verdict(of item: Components.Schemas.ActivityItem) -> (stage: PerpsWithdrawStage, status: String)? {
        let status = item.status?.split(separator: "(").first.map(String.init)?.trimmingCharacters(in: .whitespaces).lowercased()
        switch status {
        case "claimable": return (.settled, "claimable")
        case "completed": return (.settled, "completed")
        case let .some(status) where status == "failed" || status == "refunded": return (.rejected, status)
        default: return nil
        }
    }

    private static func lighterExecutionTime(hash: String) async throws -> Int64? {
        var url = URLComponents(string: "https://mainnet.zklighter.elliot.ai/api/v1/tx")!
        url.queryItems = [.init(name: "by", value: "hash"), .init(name: "value", value: hash)]
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url.url!, timeoutInterval: 5))
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return try decodeExecutionTime(data, httpStatus: response.statusCode)
    }

    static func decodeExecutionTime(_ data: Data, httpStatus: Int = 200) throws -> Int64? {
        struct Transaction: Decodable {
            let code: Int
            let status: Int?
            let executed_at: Int64?
        }
        let transaction = try JSONDecoder().decode(Transaction.self, from: data)
        if transaction.code == 21500 { return nil }
        guard httpStatus == 200, transaction.code == 200 else { throw URLError(.badServerResponse) }
        guard let status = transaction.status, status != 0,
              let executedAt = transaction.executed_at, executedAt > 0
        else { return nil }
        return executedAt
    }

    private func markUnconfirmed(
        _ operation: PerpsPendingFundingOperation,
        reason: String
    ) async throws -> (operation: PerpsPendingFundingOperation, shouldPoll: Bool) {
        let updated = try await journal.updateFunding(operationId: operation.operationId, expectedRevision: operation.revision) { current in
            guard var value = current.withdraw else { return }
            value.stage = .unconfirmed
            value.failureReason = reason
            current.details = .withdraw(value)
        }
        return (updated, false)
    }

    private func publish(_ next: PerpsFundingState) {
        guard state != next else { return }
        state = next
        for continuation in observers.values {
            continuation.yield(next)
        }
    }

    private static func canRetry(_ error: Error) -> Bool {
        switch error {
        case let error as PerpsAPIError where error.isAccountCreationPending || error.isAddressNotBound:
            true
        case let PerpsAPIError.badStatus(failure):
            failure.retryable || failure.httpStatus >= 500 || [408, 429].contains(failure.httpStatus)
        case PerpsAPIError.unauthorized, PerpsAPIError.conflict, PerpsAPIError.notFound, PerpsAPIError.badUrl:
            false
        case PerpsDepositRegistrationError.missingRegistration,
             PerpsDepositRegistrationError.notADeposit,
             PerpsDepositRegistrationError.unexpectedStage:
            false
        // Refused before it was sent, and dropped from the journal with it.
        case PerpsDepositServiceError.accountCreationPending:
            false
        default:
            true
        }
    }
}
