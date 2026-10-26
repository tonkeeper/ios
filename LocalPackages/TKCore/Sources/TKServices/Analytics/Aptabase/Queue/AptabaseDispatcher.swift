import Foundation
import TKLogging

protocol AptabaseURLSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AptabaseURLSession {}

struct AptabaseDispatcher {
    enum Outcome {
        case delivered
        case rejected
        case retry
    }

    /// The ingestion API refuses a batch larger than this with a 400 for the whole request.
    static let maximumBatchSize = 25

    private static let retriableStatusCodes: Set<Int> = [408, 425, 429]

    private let endpointProvider: @Sendable () -> String
    private let headers: [String: String]
    private let session: AptabaseURLSession

    /// Read the host per send so queued events follow boot configuration updates.
    init(
        endpointProvider: @escaping @Sendable () -> String,
        appKey: String,
        environment: AptabaseEnvironment,
        session: AptabaseURLSession
    ) {
        self.endpointProvider = endpointProvider
        headers = [
            "Content-Type": "application/json",
            "App-Key": appKey,
            "User-Agent": environment.userAgent,
        ]
        self.session = session
    }

    func send(_ events: [AptabaseEvent]) async -> Outcome {
        guard !events.isEmpty else { return .delivered }
        guard let body = try? AptabaseCoding.wireEncoder.encode(events) else {
            Log.w("Aptabase: dropping \(events.count) events that failed to encode")
            return .rejected
        }

        guard let url = URL(string: "\(endpointProvider())/api/v0/events") else {
            Log.w("Aptabase: dropping \(events.count) events, endpoint is not a URL")
            return .rejected
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200 ..< 300).contains(statusCode) {
                return .delivered
            }

            if statusCode >= 500 || Self.retriableStatusCodes.contains(statusCode) {
                Log.w("Aptabase: retrying \(events.count) events after status \(statusCode)")
                return .retry
            }
            let reason = String(data: data, encoding: .utf8) ?? ""
            Log.w("Aptabase: dropping \(events.count) events, status \(statusCode) \(reason)")
            return .rejected
        } catch {
            return .retry
        }
    }
}
