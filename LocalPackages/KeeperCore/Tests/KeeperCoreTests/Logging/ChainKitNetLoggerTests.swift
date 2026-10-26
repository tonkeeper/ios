import ChainKit
import Foundation
@testable import KeeperCore
import TKLogging
import XCTest

final class ChainKitNetLoggerTests: XCTestCase {
    func testABroadcastEventKeepsItsSeverityAndFields() throws {
        let body = #"{"error":"invalid_request"}"#
        let refused = try recorded(message: "RPC broadcast response", details: ["response_body": body, "x-request-id": "trace-123"], level: .error)
        XCTAssertEqual(refused.severity, .error)
        XCTAssertEqual(refused.extraInfo["response_body"], body)
        XCTAssertEqual(refused.extraInfo["x-request-id"], "trace-123")

        let request = try recorded(message: "RPC broadcast request", details: ["request_txID": "abc"], level: .info)
        XCTAssertEqual(request.severity, .info)
        XCTAssertEqual(request.extraInfo["request_txID"], "abc")
    }

    func testResponseDetailsSurviveLocalFileExport() throws {
        let original = Log.configuration
        defer { Log.configuration = original }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TronLogs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = SessionLogBackend(directory: directory)
        Log.configuration = LoggingConfiguration(minimumSeverity: .info, backends: [backend])
        let body = #"{"error":"invalid_request","details":""# + String(repeating: "x", count: 5000) + #""}"#
        ChainKitNetLogger().log(message: "RPC broadcast response", details: ["response_body": body, "x-request-id": "trace-export"], level: .warning)
        let url = try LogExporter.exportToTemporaryFile(sessionLog: backend, filenamePrefix: "TronDiagnostics")
        defer { try? FileManager.default.removeItem(at: url) }
        let exported = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(exported.contains(body))
        XCTAssertTrue(exported.contains("trace-export"))
        XCTAssertTrue(exported.contains("Build number:"))
    }

    private func recorded(message: String, details: [String: String], level: ModuleLoggerLevel) throws -> LogRecord {
        let original = Log.configuration
        defer { Log.configuration = original }
        let backend = RecordingBackend()
        Log.configuration = LoggingConfiguration(minimumSeverity: .info, backends: [backend])
        ChainKitNetLogger().log(message: message, details: details, level: level)
        return try XCTUnwrap(backend.records.last)
    }
}

private final class RecordingBackend: LogBackend {
    var records = [LogRecord]()
    func log(_ record: LogRecord) {
        records.append(record)
    }
}
