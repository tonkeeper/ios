import Foundation
import TKLogging

/// Lighter opens every account on Standard and pays no integrator fee on trades from it, so
/// the account is moved to Plus. tk-perps relays the switch but cannot authorize it — it holds
/// no key that may sign for the account — so the device signs the authorization with its
/// trading key and hands it over.
///
/// Premium also pays the fee, and moving off it is a downgrade, so only Standard is changed.
/// Nothing is persisted: Lighter is the record, and a settled account is not read again for the
/// life of the process. An unsettled one is read at most once per `recheckInterval` on resolve;
/// activation and trades read it at once.
final class PerpsAccountTierUpgrader: @unchecked Sendable {
    enum Trigger: String, Sendable {
        case activation
        case resolve
        case trade
    }

    static let targetTier = "plus"
    static let attempts = 3
    static let recheckInterval: TimeInterval = 60

    private let retryDelayNanoseconds: UInt64
    /// A trade waits this long for an unsettled account, then goes ahead on whatever tier it has.
    private let tradeWaitNanoseconds: UInt64
    private let now: @Sendable () -> Date

    private let lock = NSLock()
    private var settled = Set<Int64>()
    private var checkedAt = [Int64: Date]()
    private var running = [Int64: Task<Void, Never>]()

    init(
        retryDelayNanoseconds: UInt64 = 2_000_000_000,
        tradeWaitNanoseconds: UInt64 = 3_000_000_000,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.tradeWaitNanoseconds = tradeWaitNanoseconds
        self.now = now
    }

    func ensurePlus(
        accountIndex: Int64,
        trigger: Trigger,
        readTier: @escaping @Sendable () async throws -> String,
        changeTier: @escaping @Sendable (_ newTier: String) async throws -> Void
    ) async {
        let (task, decision) = lock.withLock { () -> (Task<Void, Never>?, String) in
            if settled.contains(accountIndex) { return (nil, "skip settled") }
            if let running = running[accountIndex] { return (running, "join running") }
            let sinceCheck = now().timeIntervalSince(checkedAt[accountIndex] ?? .distantPast)
            if trigger == .resolve, sinceCheck < Self.recheckInterval {
                return (nil, "skip checked \(Int(sinceCheck))s ago")
            }
            checkedAt[accountIndex] = now()
            let task = Task {
                await self.run(accountIndex: accountIndex, trigger: trigger, readTier: readTier, changeTier: changeTier)
            }
            running[accountIndex] = task
            return (task, "start")
        }
        Log.perps.d("tier: ensure trigger=\(trigger.rawValue) account=\(accountIndex) → \(decision)")
        guard let task else { return }
        guard trigger == .trade else {
            await task.value
            return
        }
        let startedAt = Date()
        let finished = await wait(for: task, atMostNanoseconds: tradeWaitNanoseconds)
        let waitedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let isSettled = lock.withLock { settled.contains(accountIndex) }
        if finished {
            Log.perps.i("tier: trade waited \(waitedMs)ms settled=\(isSettled) account=\(accountIndex)")
        } else {
            Log.perps.w("tier: trade proceeds before the tier settled, waited \(waitedMs)ms account=\(accountIndex)")
        }
    }

    private func wait(for task: Task<Void, Never>, atMostNanoseconds limit: UInt64) async -> Bool {
        let (outcome, continuation) = AsyncStream<Bool>.makeStream()
        Task {
            await task.value
            continuation.yield(true)
        }
        let timer = Task {
            try? await Task.sleep(nanoseconds: limit)
            continuation.yield(false)
        }
        defer { timer.cancel() }
        for await finished in outcome {
            return finished
        }
        return false
    }

    private func run(
        accountIndex: Int64,
        trigger: Trigger,
        readTier: @Sendable () async throws -> String,
        changeTier: @Sendable (String) async throws -> Void
    ) async {
        defer { lock.withLock { running[accountIndex] = nil } }
        for attempt in 1 ... Self.attempts {
            Log.perps.d("tier: attempt \(attempt)/\(Self.attempts) trigger=\(trigger.rawValue) account=\(accountIndex)")
            do {
                let tier = try await readTier().lowercased()
                Log.perps.i("tier: account=\(accountIndex) tier=\(tier)")
                if tier == "standard" {
                    Log.perps.d("tier: changing account=\(accountIndex) from=\(tier) to=\(Self.targetTier)")
                    try await changeTier(Self.targetTier)
                    Log.perps.i("tier: upgraded account=\(accountIndex) tier=\(Self.targetTier)")
                }
                lock.withLock { _ = settled.insert(accountIndex) }
                Log.perps.i("tier: settled account=\(accountIndex) trigger=\(trigger.rawValue) attempt=\(attempt)")
                return
            } catch where attempt < Self.attempts && PerpsExecutionRelay.isAmbiguous(PerpsTradingErrorMapper.map(error)) {
                Log.perps.w("tier: retrying account=\(accountIndex) attempt=\(attempt)", error: error)
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            } catch {
                Log.perps.w("tier: upgrade failed account=\(accountIndex) trigger=\(trigger.rawValue) attempt=\(attempt)", error: error)
                return
            }
        }
    }
}
