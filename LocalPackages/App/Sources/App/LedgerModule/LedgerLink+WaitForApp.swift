import Foundation
import LedgerKit
import TKLogging

extension LedgerLink {
    /// Polls until `app` is open and returns its version. A refused or missing app is asked for again,
    /// so installing it lets the screen go on; `isMissing` hears every answer that tells whether the
    /// app is on the device.
    func waitForApp(
        _ app: LedgerApp,
        sleep: @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        isMissing: @MainActor (Bool) -> Void
    ) async throws -> String {
        while true {
            do {
                if let version = try await open(app) {
                    return version
                }
            } catch let error as LedgerStatusError {
                Log.i("Ledger did not open the \(app.name) app, asking again", error: error)
                await isMissing(error.isAppMissing)
            }
            try await sleep(1_000_000_000)
        }
    }
}
