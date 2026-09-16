import Foundation
import TKLogging
import XCTest

final class LoggableErrorTests: XCTestCase {
    func testLogDomainStoresCanonicalErrorDescription() {
        let backend = RecordingLogBackend()
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(
            minimumSeverity: .debug,
            defaultSubsystem: "test",
            backends: [backend]
        )

        LogDomain(category: "test").w(
            "operation failed",
            error: TestLoggableError.failed,
            extraInfo: [
                "error": "manual-value",
                "requestId": "request-1",
            ]
        )

        XCTAssertEqual(backend.records.count, 1)
        XCTAssertEqual(backend.records.first?.extraInfo["error"], "type=TestLoggableError, case=failed")
        XCTAssertEqual(backend.records.first?.extraInfo["requestId"], "request-1")
    }

    func testUnknownErrorDescriptionExcludesLocalizedMessage() {
        let error = UnknownError()

        XCTAssertTrue(error.logDescription.contains("type="))
        XCTAssertTrue(error.logDescription.contains("domain="))
        XCTAssertTrue(error.logDescription.contains("code="))
        XCTAssertFalse(error.logDescription.contains("sensitive diagnostic"))
    }

    func testDecodingErrorDescriptionIncludesCaseAndPathWithoutValues() {
        struct Payload: Decodable {
            let transaction: Transaction

            struct Transaction: Decodable {
                let amount: String
            }
        }
        let data = Data(#"{"transaction":{"amount":42}}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(Payload.self, from: data)) { error in
            XCTAssertEqual(
                error.logDescription,
                "type=Swift.DecodingError, case=typeMismatch, expected=String, path=transaction.amount"
            )
        }
    }

    func testDecodingErrorDescriptionIncludesMissingKey() {
        struct Payload: Decodable {
            let amount: String
        }
        let data = Data(#"{"value":"secret-value"}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(Payload.self, from: data)) { error in
            XCTAssertEqual(
                error.logDescription,
                "type=Swift.DecodingError, case=keyNotFound, key=amount"
            )
            XCTAssertFalse(error.logDescription.contains("secret-value"))
        }
    }

    func testFilteredLogDoesNotBuildErrorDescription() {
        let backend = RecordingLogBackend()
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(
            minimumSeverity: .error,
            defaultSubsystem: "test",
            backends: [backend]
        )
        let error = CountingLoggableError()

        LogDomain(category: "test").d("ignored", error: error)

        XCTAssertEqual(error.descriptionCallCount, 0)
        XCTAssertTrue(backend.records.isEmpty)
    }
}

private enum TestLoggableError: LoggableError {
    case failed

    var logDescription: String {
        "type=TestLoggableError, case=failed"
    }
}

private struct UnknownError: LocalizedError {
    var errorDescription: String? {
        "sensitive diagnostic"
    }
}

private final class CountingLoggableError: LoggableError {
    private(set) var descriptionCallCount = 0

    var logDescription: String {
        descriptionCallCount += 1
        return "type=CountingLoggableError"
    }
}

private final class RecordingLogBackend: LogBackend {
    private(set) var records = [LogRecord]()

    func log(_ record: LogRecord) {
        records.append(record)
    }
}
