import Foundation
import TKKeychain

extension TKKeychainVault {
    /// Recreates a biometry-protected item: deletes the existing one so the new
    /// access control actually takes effect, then writes the new value. The
    /// delete is required for migration — an in-place update keeps the stale ACL
    /// (a legacy `.biometryAny` item would never become `.biometryCurrentSet`)
    /// and reading to update prompts for biometry.
    ///
    /// A single keychain item can't be replaced transactionally, so a failure
    /// between the delete and the write propagates to the caller. Recovery is at
    /// a higher layer: the next successful passcode entry re-saves the value, so
    /// the only fallout is the biometric unlock shortcut being unavailable until
    /// then (the mnemonics are still decryptable with the entered passcode).
    func recreateItem(_ value: String, query: TKKeychainQuery) throws {
        do {
            try delete(query)
        } catch TKKeychainError.noItem {}
        try set(value, query: query)
    }
}
