import Foundation
import TronSwiftAPI

/// A node gives a transaction roughly a minute; the local +10 min extension is applied before the
/// passcode screen, so a slow signature can still outlive it. Recovering means redoing the whole
/// build → sign → send, because a new expiration is a new `txID`.
enum TronExpirationRetry {
    /// A transaction found expired before it was signed, which the chain would refuse as one.
    struct Expired: Error {}

    /// `isEnabled` is false for the battery relay: it fails with the backend's own error type, and
    /// a repeat could pay twice for a send the backend has already accepted.
    static func run<T>(isEnabled: Bool, _ attempt: () async throws -> T) async rethrows -> T {
        do {
            return try await attempt()
        } catch {
            guard isEnabled, error is Expired || (error as? TronApi.Error)?.isExpiredTronTransaction == true else {
                throw error
            }
            return try await attempt()
        }
    }
}
