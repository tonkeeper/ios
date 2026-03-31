import Foundation

struct RateLimiterMiddleware: HttpApiMiddleware {
    private let rateLimiter: RequestRateLimiter

    init(rateLimiter: RequestRateLimiter) {
        self.rateLimiter = rateLimiter
    }

    func execute(
        request _: URLRequest,
        next: @escaping HttpApiTransportOperation
    ) async throws -> HttpApiTransportPayload {
        await rateLimiter.waitForPermit()
        return try await next()
    }
}
