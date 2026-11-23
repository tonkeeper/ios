import Foundation

private let eventBalanceHint = "balance.hint"
private let eventActivityHint = "activity.hint"
private let hintDebounceNanoseconds: UInt64 = 400_000_000

final class MultichainWalletHints: MultichainRealtimeEventHandler {
    private let balanceChangeObservers = LockedObserverStore<String>()
    private let historyInvalidationObservers = LockedObserverStore<String>()
    private var seq = MultichainRealtimeSeqFilter()
    private var balanceHintTask: Task<Void, Never>?
    private var activityHintTask: Task<Void, Never>?

    func addBalanceChangeObserver<T: AnyObject>(_ observer: T, closure: @escaping (T, String) -> Void) {
        balanceChangeObservers.add(observer, closure: closure)
    }

    func addHistoryInvalidationObserver<T: AnyObject>(_ observer: T, closure: @escaping (T, String) -> Void) {
        historyInvalidationObservers.add(observer, closure: closure)
    }

    func accept(_ envelope: MultichainRealtimeEnvelope, payload _: Data) -> Bool {
        switch envelope.event {
        case eventBalanceHint:
            if isNew(envelope) {
                scheduleBalanceHint(walletId: envelope.walletId)
            }
        case eventActivityHint:
            if isNew(envelope) {
                scheduleActivityHint(walletId: envelope.walletId)
            }
        default:
            return false
        }
        return true
    }

    func resync(walletId: String) {
        scheduleBalanceHint(walletId: walletId)
        scheduleActivityHint(walletId: walletId)
    }

    func cancelPending() {
        balanceHintTask?.cancel()
        activityHintTask?.cancel()
    }

    private func isNew(_ envelope: MultichainRealtimeEnvelope) -> Bool {
        seq.isNew(envelope.seq, key: "\(envelope.walletId):\(envelope.event)")
    }

    private func scheduleBalanceHint(walletId: String) {
        balanceHintTask?.cancel()
        balanceHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: hintDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.balanceChangeObservers.notify(walletId)
        }
    }

    private func scheduleActivityHint(walletId: String) {
        activityHintTask?.cancel()
        activityHintTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: hintDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.historyInvalidationObservers.notify(walletId)
        }
    }
}
