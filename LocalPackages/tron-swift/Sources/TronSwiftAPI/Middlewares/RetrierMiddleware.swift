import Foundation

struct RetrierMiddleware: HttpApiMiddleware {
    private let rateLimitRetryHandler: RequestRetrier
    private let rateLimiter: RequestRateLimiter

    init(
        rateLimitRetryHandler: RequestRetrier,
        rateLimiter: RequestRateLimiter
    ) {
        self.rateLimitRetryHandler = rateLimitRetryHandler
        self.rateLimiter = rateLimiter
    }

    func execute(
        request _: URLRequest,
        next: @escaping HttpApiTransportOperation
    ) async throws -> HttpApiTransportPayload {
        var retryAttempt = 0
        while true {
            let payload = try await next()
            guard let httpResponse = payload.response as? HTTPURLResponse else {
                return payload
            }
            let decision = rateLimitRetryHandler.makeDecision(
                response: httpResponse,
                data: payload.data,
                attempt: retryAttempt
            )
            switch decision {
            case .succeeded, .outOfAttempts:
                return payload
            case let .retry(cooldown):
                await rateLimiter.applyCooldown(seconds: cooldown)
                retryAttempt += 1
            }
        }
    }
}
