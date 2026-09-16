import Foundation
import OpenAPIRuntime

/// Accepts RFC 3339 timestamps with or without fractional seconds. The runtime default
/// takes only the plain form, so a backend that starts emitting milliseconds on any single
/// field would fail the decode of the whole response.
struct MultichainDateTranscoder: DateTranscoder {
    private static let formattersLock = NSLock()
    private static let formatters: [ISO8601DateFormatter] = {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [plain, fractional]
    }()

    func encode(_ date: Date) throws -> String {
        ISO8601DateFormatter().string(from: date)
    }

    func decode(_ dateString: String) throws -> Date {
        try Self.formattersLock.withLock {
            for formatter in Self.formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Expected an RFC 3339 date, got \(dateString)")
            )
        }
    }
}
