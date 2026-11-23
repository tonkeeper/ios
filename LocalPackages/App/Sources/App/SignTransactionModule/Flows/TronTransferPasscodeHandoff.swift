import Foundation

/// Reuses one unlock across the signing steps of a send, with a longer timeout for an active
/// Battery payment. Signing takes it or the attempt clears it before that backstop expires.
@MainActor
final class TronTransferPasscodeHandoff {
    private static let lifetime: UInt64 = 20_000_000_000
    private static let operationLifetime: UInt64 = 300_000_000_000

    private var passcode: String?
    private var expirationTask: Task<Void, Never>?
    private var belongsToCurrentOperation = false

    var currentOperationPasscode: String? {
        belongsToCurrentOperation ? passcode : nil
    }

    func store(_ passcode: String) {
        discard()
        self.passcode = passcode
        expire(after: Self.lifetime)
    }

    private func expire(after lifetime: UInt64) {
        expirationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: lifetime)
            guard !Task.isCancelled else { return }
            self?.discard()
        }
    }

    func take() -> String? {
        defer { discard() }
        return passcode
    }

    func storeForCurrentOperation(_ passcode: String) {
        discard()
        self.passcode = passcode
        belongsToCurrentOperation = true
        expire(after: Self.operationLifetime)
    }

    func discard() {
        expirationTask?.cancel()
        expirationTask = nil
        passcode = nil
        belongsToCurrentOperation = false
    }
}
