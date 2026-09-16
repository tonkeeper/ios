import Foundation
@testable import KeeperCore
import TKLogging
import XCTest

final class LogDomainFailureTests: XCTestCase {
    /// Each layer restates cancellation in its own vocabulary, and every one of them has to be
    /// recognized: a superseded picker load reaching the log as a warning is the noise this is for.
    func test_domainCancellationIsReportedWithoutAWarning() {
        for error in [
            CancellationError() as any Error,
            URLError(.cancelled),
            MultichainServiceError.cancelled,
            MultichainClientAPIError.cancelled,
            MultichainRampAPIError.cancelled,
            DeviceAuthError.cancelled,
        ] {
            let record = record(failure: error)

            XCTAssertEqual(record?.severity, .info, "\(type(of: error))")
            XCTAssertEqual(record?.message, "assets loading failed - cancelled", "\(type(of: error))")
        }
    }

    func test_everythingElseStaysAWarningCarryingTheError() {
        for error in [
            MultichainServiceError.connectionError as any Error,
            MultichainClientAPIError.badStatus(message: "nope"),
            DeviceAuthError.unauthorized(reason: "token_expired"),
        ] {
            let record = record(failure: error)

            XCTAssertEqual(record?.severity, .warning, "\(type(of: error))")
            XCTAssertEqual(record?.message, "assets loading failed", "\(type(of: error))")
            XCTAssertEqual(record?.extraInfo["error"], error.logDescription, "\(type(of: error))")
        }
    }
}

private extension LogDomainFailureTests {
    func record(failure error: any Error) -> LogRecord? {
        let backend = RecordingLogBackend()
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(
            minimumSeverity: .debug,
            defaultSubsystem: "test",
            backends: [backend]
        )

        LogDomain(category: "test").failure("assets loading failed", error: error)

        return backend.records.last
    }
}

private final class RecordingLogBackend: LogBackend {
    private(set) var records = [LogRecord]()

    func log(_ record: LogRecord) {
        records.append(record)
    }
}
