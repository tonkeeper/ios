import Foundation
import PerpsModels

/// The pill in place of the Perps title that follows a withdrawal: sending while it is signed and
/// sent, then "sent" once Lighter accepts it and "confirmed" once it settles, each for a while.
/// Only a withdrawal this screen saw unresolved, or one that appeared after it opened, is announced.
@MainActor
public final class PerpsWithdrawStatusViewModel: ObservableObject {
    enum Status: Equatable {
        case sending(String)
        case sent(String)
        case confirmed(String)
        case failed(String)

        var operationId: String {
            switch self {
            case let .sending(id), let .sent(id), let .confirmed(id), let .failed(id): id
            }
        }
    }

    @Published private(set) var status: Status?
    public var onOpenHistory: ((_ operationId: String) -> Void)?

    private let accountStore: any PerpsAccountStoring
    private let lifetime: @Sendable () async -> Void
    private let preexisting: Set<String>
    private var watched: Set<String> = []
    private var announced: [String: Status] = [:]
    private(set) var hideTask: Task<Void, Never>?

    public init(
        accountStore: any PerpsAccountStoring,
        lifetime: @escaping @Sendable () async -> Void = { try? await Task.sleep(nanoseconds: 6_000_000_000) }
    ) {
        self.accountStore = accountStore
        self.lifetime = lifetime
        let activity = accountStore.fundingActivity()
        preexisting = activity.withdrawals
        // Accepted before the screen opened: its "sent" moment is gone, its outcome is still ahead.
        for id in activity.withdrawals.intersection(activity.pending) {
            announced[id] = .sent(id)
        }
        apply(activity)
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.apply(observer.accountStore.fundingActivity()) }
        }
    }

    func apply(_ activity: PerpsFundingActivity) {
        let withdrawals = activity.withdrawals
        let sending = withdrawals.intersection(activity.inFlight)
        watched.formUnion(withdrawals.subtracting(activity.ended))

        if let id = sending.min() {
            show(.sending(id), expires: false)
            return
        }
        let eligible = withdrawals.filter { watched.contains($0) || !preexisting.contains($0) }
        let next = eligible.sorted().compactMap { id -> Status? in
            let status: Status? = if activity.failed.contains(id) {
                .failed(id)
            } else if activity.completed.contains(id) {
                .confirmed(id)
            } else if activity.pending.contains(id) {
                .sent(id)
            } else {
                nil
            }
            guard let status, announced[id] != status else { return nil }
            return status
        }.max { $0.priority < $1.priority }
        if let next {
            announced[next.operationId] = next
            show(next, expires: true)
        } else if case .sending = status {
            hide()
        }
    }

    func tap() {
        guard let status else { return }
        if case .failed = status {
            hide()
        } else {
            onOpenHistory?(status.operationId)
        }
    }

    private func show(_ next: Status, expires: Bool) {
        hideTask?.cancel()
        hideTask = nil
        if status != next { status = next }
        guard expires else { return }
        hideTask = Task { [weak self, lifetime] in
            await lifetime()
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        hideTask?.cancel()
        hideTask = nil
        status = nil
    }
}

private extension PerpsWithdrawStatusViewModel.Status {
    /// Several withdrawals changing at once: a failure is the one the user must not miss.
    var priority: Int {
        switch self {
        case .sending: 0
        case .sent: 1
        case .confirmed: 2
        case .failed: 3
        }
    }
}
