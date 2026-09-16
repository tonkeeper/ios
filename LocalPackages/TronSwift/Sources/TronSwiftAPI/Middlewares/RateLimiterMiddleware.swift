import Foundation

struct RateLimiterMiddleware: HttpApiMiddleware {
    private let rateLimiter: RequestRateLimiter

    init(rateLimiter: RequestRateLimiter) {
        self.rateLimiter = rateLimiter
    }

    func execute(
        request: URLRequest,
        next: @escaping HttpApiTransportOperation
    ) async throws -> HttpApiTransportPayload {
        await rateLimiter.waitForPermit(key: Self.methodKey(for: request.url?.path ?? ""))
        return try await next()
    }

    /// TronGrid throttles per API method (429 body: "request rate of (getAccount)
    /// exceeded the allowed_rps(1)"), so pacing is keyed by the normalized path,
    /// with address-like segments collapsed to keep one key per method.
    static func methodKey(for path: String) -> String {
        path.split(separator: "/")
            .map { $0.count >= 25 ? "*" : String($0) }
            .joined(separator: "/")
    }
}
