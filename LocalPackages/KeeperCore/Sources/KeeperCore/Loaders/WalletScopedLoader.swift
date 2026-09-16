import Foundation

public enum WalletScope {
    case activeWallet
    case walletId(String?)
}

actor WalletScopedLoader<Content> {
    typealias Output = (walletId: String?, content: Content)

    private struct Run {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<Content, Never>]
    }

    private let walletsStore: WalletsStore
    private let fetch: (String?) async -> Content
    private let apply: (String?, Content) async -> Void

    private var runs = [String?: Run]()

    init(
        walletsStore: WalletsStore,
        fetch: @escaping (String?) async -> Content,
        apply: @escaping (String?, Content) async -> Void
    ) {
        self.walletsStore = walletsStore
        self.fetch = fetch
        self.apply = apply
    }

    @discardableResult
    func reload(scope: WalletScope, force: Bool) async -> Output {
        let walletId = walletId(for: scope)
        let content = await withCheckedContinuation { continuation in
            enqueue(walletId: walletId, force: force, continuation: continuation)
        }
        return (walletId, content)
    }

    private func enqueue(
        walletId: String?,
        force: Bool,
        continuation: CheckedContinuation<Content, Never>
    ) {
        var waiters = runs[walletId]?.waiters ?? [:]
        waiters[UUID()] = continuation

        guard force || runs[walletId] == nil else {
            runs[walletId]?.waiters = waiters
            return
        }
        runs[walletId]?.task.cancel()
        start(walletId: walletId, waiters: waiters)
    }

    private func start(walletId: String?, waiters: [UUID: CheckedContinuation<Content, Never>]) {
        let id = UUID()
        let fetch = fetch
        let task = Task { [weak self] in
            let content = await fetch(walletId)
            await self?.finish(walletId: walletId, id: id, content: content)
        }
        runs[walletId] = Run(id: id, task: task, waiters: waiters)
    }

    private func finish(walletId: String?, id: UUID, content: Content) async {
        guard runs[walletId]?.id == id else { return }
        await apply(walletId, content)
        guard let run = runs[walletId], run.id == id else { return }
        runs[walletId] = nil
        for waiter in run.waiters.values {
            waiter.resume(returning: content)
        }
    }

    private func walletId(for scope: WalletScope) -> String? {
        switch scope {
        case .activeWallet:
            (try? walletsStore.activeWallet)?.multichainWalletState?.walletId
        case let .walletId(walletId):
            walletId
        }
    }
}
