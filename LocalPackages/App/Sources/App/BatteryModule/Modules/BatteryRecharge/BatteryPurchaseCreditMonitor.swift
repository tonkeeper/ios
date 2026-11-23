import Foundation

@MainActor
final class BatteryPurchaseCreditMonitor {
    enum Result: Equatable {
        case credited
        case delayed
    }

    private let loadBalance: () async throws -> NSDecimalNumber
    private let refresh: () async -> Void
    private let wait: () async throws -> Void
    private let attempts: Int

    init(loadBalance: @escaping () async throws -> NSDecimalNumber, refresh: @escaping () async -> Void, attempts: Int = 30, wait: @escaping () async throws -> Void = { try await Task.sleep(nanoseconds: 2_000_000_000) }) {
        self.loadBalance = loadBalance
        self.refresh = refresh
        self.attempts = attempts
        self.wait = wait
    }

    /// A submitted payment must finish reconciliation even after its screen closes.
    func start(after balance: NSDecimalNumber, minimumIncreaseTON: NSDecimalNumber? = .zero, completion: @escaping (Result) -> Void) -> Task<Void, Never> {
        Task { [loadBalance, refresh, wait, attempts] in
            await refresh()
            guard !Task.isCancelled else { return }
            guard let minimumIncreaseTON else {
                completion(.delayed)
                return
            }
            for attempt in 0 ..< attempts {
                guard !Task.isCancelled else { return }
                if let current = try? await loadBalance(), current.compare(balance) == .orderedDescending,
                   current.subtracting(balance).compare(minimumIncreaseTON) != .orderedAscending
                {
                    await refresh()
                    guard !Task.isCancelled else { return }
                    completion(.credited)
                    return
                }
                if attempt + 1 < attempts {
                    do { try await wait() } catch { return }
                }
            }
            await refresh()
            guard !Task.isCancelled else { return }
            completion(.delayed)
        }
    }
}
