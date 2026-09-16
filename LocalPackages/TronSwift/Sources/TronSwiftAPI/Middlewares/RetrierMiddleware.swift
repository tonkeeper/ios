import Foundation
import TKLogging

struct RetrierMiddleware: HttpApiMiddleware {
    private let rateLimitRetryHandler: RequestRetrier

    init(rateLimitRetryHandler: RequestRetrier) {
        self.rateLimitRetryHandler = rateLimitRetryHandler
    }

    func execute(
        request: URLRequest,
        next: @escaping HttpApiTransportOperation
    ) async throws -> HttpApiTransportPayload {
        var retryAttempt = 0
        while true {
            let payload: HttpApiTransportPayload
            do {
                payload = try await next()
            } catch {
                guard !Task.isCancelled,
                      case let .retry(cooldown) = rateLimitRetryHandler.retryDecision(
                          request: request,
                          attempt: retryAttempt
                      )
                else {
                    throw error
                }
                await sleep(cooldown: cooldown)
                retryAttempt += 1
                continue
            }
            guard let httpResponse = payload.response as? HTTPURLResponse else {
                return payload
            }
            let decision = rateLimitRetryHandler.makeDecision(
                request: request,
                response: httpResponse,
                data: payload.data,
                attempt: retryAttempt
            )
            switch decision {
            case .succeeded:
                return payload
            case .outOfAttempts:
                Log.migration.w("tron request out of retry attempts", extraInfo: [
                    "path": request.url?.path ?? "-",
                    "status": "\(httpResponse.statusCode)",
                ])
                return payload
            case let .retry(cooldown):
                Log.migration.w("tron request retrying after cooldown", extraInfo: [
                    "path": request.url?.path ?? "-",
                    "status": "\(httpResponse.statusCode)",
                    "attempt": "\(retryAttempt + 1)",
                    "cooldownS": "\(cooldown)",
                ])
                await sleep(cooldown: cooldown)
                retryAttempt += 1
            }
        }
    }

    /// Cooldown is per-request: pushing it into the shared rate limiter would stall
    /// every Tron call in the app behind one throttled endpoint.
    private func sleep(cooldown: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, cooldown) * 1_000_000_000))
    }
}
