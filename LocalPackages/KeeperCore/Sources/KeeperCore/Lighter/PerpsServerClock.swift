import Foundation
import HTTPTypes
import OpenAPIRuntime

final class PerpsServerClock: @unchecked Sendable {
    static let shared = PerpsServerClock()

    static let maxDeviceSkewMs: Int64 = 60 * 1000

    private let lock = NSLock()
    private var offsetMs: Int64?

    var serverOffsetMs: Int64? {
        lock.withLock { offsetMs }
    }

    func record(serverDate: Date, receivedAt: Date = Date()) {
        let offset = Int64(((serverDate.timeIntervalSince1970 - receivedAt.timeIntervalSince1970) * 1000).rounded())
        lock.withLock { offsetMs = offset }
    }

    func serverNowUnixMs(deviceNowUnixMs: Int64 = PerpsPlannerMapping.nowUnixMs()) -> Int64 {
        deviceNowUnixMs + (serverOffsetMs ?? 0)
    }

    static func isDeviceClockSkewed(serverOffsetMs: Int64) -> Bool {
        abs(serverOffsetMs) > maxDeviceSkewMs
    }
}

struct PerpsServerClockMiddleware: ClientMiddleware {
    let clock: PerpsServerClock

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        if let value = response.headerFields[.date], let serverDate = httpDateFormatter.date(from: value) {
            clock.record(serverDate: serverDate)
        }
        return (response, responseBody)
    }
}

private let httpDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return formatter
}()
