import Foundation
import KeeperCore

@MainActor
protocol TradeAssetDetailsHotWindowObserver: AnyObject {
    func hotWindowDidTick() async
}

/// The balance loader's hot phase, for screens that read their own source and so do not follow the
/// loader polling faster.
///
/// Lives for the session rather than for a screen: the window is open because a transfer was just
/// sent, not because someone is looking. A details screen opened seconds after a send joins a
/// window that is already running instead of starting a private one — and one opened after the
/// window closed starts nothing.
///
/// Entering and extending are the same call. The deadline moves, the loop already running keeps its
/// cadence, and a second send cannot start a second loop.
@MainActor
final class TradeAssetDetailsHotWindow {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    private struct Entry {
        weak var observer: (any TradeAssetDetailsHotWindowObserver)?
        let wallet: Wallet
    }

    private let interval: TimeInterval
    private let duration: TimeInterval
    private let now: () -> Date
    private let sleep: Sleep
    private let notificationCenter: NotificationCenter

    private var deadlines = [Wallet: Date]()
    private var entries = [Entry]()
    private var task: Task<Void, Never>?
    private var transactionSendToken: NSObjectProtocol?

    init(
        interval: TimeInterval = 2,
        duration: TimeInterval = 14,
        now: @escaping () -> Date = { Date() },
        sleep: @escaping Sleep = TradeAssetDetailsHotWindow.defaultSleep,
        notificationCenter: NotificationCenter = .default
    ) {
        self.interval = interval
        self.duration = duration
        self.now = now
        self.sleep = sleep
        self.notificationCenter = notificationCenter

        transactionSendToken = notificationCenter.addObserver(
            forName: .transactionSendNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let wallet = notification.userInfo?["wallet"] as? Wallet
            Task { @MainActor in
                guard let wallet else { return }
                self?.extend(wallet: wallet)
            }
        }
    }

    deinit {
        if let transactionSendToken {
            notificationCenter.removeObserver(transactionSendToken)
        }
        task?.cancel()
    }

    /// Observers are held weakly and register for one wallet: a send on another wallet is not this
    /// screen's business.
    func addObserver(_ observer: some TradeAssetDetailsHotWindowObserver, wallet: Wallet) {
        entries.removeAll { $0.observer == nil || $0.observer === observer }
        entries.append(Entry(observer: observer, wallet: wallet))
    }

    func extend(wallet: Wallet) {
        deadlines[wallet] = now().addingTimeInterval(duration)
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            await run()
        }
    }

    private func run() async {
        defer { task = nil }

        while !openWallets().isEmpty {
            do {
                try await sleep(interval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await notify(wallets: openWallets())
        }
    }

    private func openWallets() -> Set<Wallet> {
        let date = now()
        deadlines = deadlines.filter { $0.value > date }
        return Set(deadlines.keys)
    }

    /// Ticks are delivered one at a time and awaited, so the interval spaces finished refreshes
    /// rather than stacking them.
    private func notify(wallets: Set<Wallet>) async {
        entries.removeAll { $0.observer == nil }
        for entry in entries where wallets.contains(entry.wallet) {
            await entry.observer?.hotWindowDidTick()
        }
    }
}

extension TradeAssetDetailsHotWindow {
    nonisolated static let defaultSleep: Sleep = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}
