import Foundation

struct MultichainSwapRouteRecovery: Sendable {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    /// One pause per recovery attempt. The list also bounds the ladder: once it runs out the
    /// stale-route failure is what the user sees.
    let delays: [TimeInterval]
    let sleep: Sleep

    static let `default` = MultichainSwapRouteRecovery(
        delays: [0.5, 1, 2],
        sleep: { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    )
}
