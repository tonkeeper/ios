import KeeperCore

extension MnemonicAccess {
    /// Stores the biometry-protected passcode and reads it back, so the system biometry
    /// prompt shows right away and a declined prompt throws instead of surfacing at the
    /// next transaction or unlock.
    func setBiometryProtectedPasscode(_ passcode: String) async throws {
        try setPasscode(passcode)
        let access = self
        // The read blocks for the whole prompt, so it must not run on the main actor.
        _ = try await Task.detached(priority: .userInitiated) {
            try access.getPasscode()
        }.value
    }
}
