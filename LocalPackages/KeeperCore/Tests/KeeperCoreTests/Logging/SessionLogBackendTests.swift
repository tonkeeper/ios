import Foundation
import TKLogging
import XCTest

final class SessionLogBackendTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionLogBackendTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    func testExportListsSessionsOldestFirstWithTheSessionInfoAboveItsRecords() throws {
        let evening = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        evening.log(record("swap failed"))
        _ = try exported(evening)
        let morning = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 50000))
        morning.log(record("logs exported"))

        XCTAssertEqual(try exported(morning), [
            "===== session 1970-01-01T00:16:40.000Z =====",
            "<environment>",
            "swap failed",
            "===== session 1970-01-01T13:53:20.000Z =====",
            "<environment>",
            "logs exported",
        ])
    }

    func testALongSessionLosesItsOldestRecordsAndSaysSo() throws {
        let sessionLog = SessionLogBackend(
            directory: directory,
            startedAt: Date(timeIntervalSince1970: 1000),
            segmentBytes: 100,
            budgetBytes: 300
        )
        for index in 0 ..< 20 {
            sessionLog.log(record("line \(index)"))
        }

        let shape = try exported(sessionLog)

        XCTAssertEqual(Array(shape.prefix(3)), [
            "===== session 1970-01-01T00:16:40.000Z =====",
            "<environment>",
            "--- earlier records of this session were removed to stay within the size limit",
        ])
        XCTAssertEqual(shape.last, "line 19")
        XCTAssertFalse(shape.contains("line 0"))
    }

    func testStartingASessionRemovesOldSessionsThatNoLongerFit() throws {
        let old = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        old.log(record("old"))
        _ = try exported(old)
        let current = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 2000), budgetBytes: 1)
        current.log(record("current"))

        XCTAssertEqual(try exported(current), [
            "===== session 1970-01-01T00:33:20.000Z =====",
            "<environment>",
            "current",
        ])
    }

    func testANewSessionRemovesWholeOldSessionsOldestFirst() throws {
        let oldest = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        for _ in 0 ..< 1000 {
            oldest.log(record(UUID().uuidString))
        }
        _ = try exported(oldest)
        let older = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 2000))
        older.log(record("kept"))
        _ = try exported(older)
        let current = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 3000), budgetBytes: 5000)
        current.log(record("current"))

        XCTAssertEqual(try exported(current), [
            "===== session 1970-01-01T00:33:20.000Z =====",
            "<environment>",
            "kept",
            "===== session 1970-01-01T00:50:00.000Z =====",
            "<environment>",
            "current",
        ])
    }

    func testAFinishedSessionIsKeptAsOneCompressedFileNamedWithItsTextSize() throws {
        let finished = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        finished.log(record("swap failed"))
        _ = try exported(finished)
        let current = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 2000))
        _ = try exported(current)

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("1000000.") }
        let archive = try XCTUnwrap(files.first)
        let nameParts = archive.split(separator: ".")
        let text = try (Data(contentsOf: directory.appendingPathComponent(archive)) as NSData).decompressed(using: .lzfse)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(nameParts.last, "lzfse")
        XCTAssertEqual(nameParts.dropFirst().first.flatMap { Int($0) }, text.length)
    }

    func testRawFilesLeftNextToAnArchiveAreRemoved() throws {
        let finished = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        finished.log(record("swap failed"))
        _ = try exported(finished)
        _ = try exported(SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 2000)))
        let leftover = directory.appendingPathComponent("1000000.0.log")
        try Data("leftover\n".utf8).write(to: leftover)
        let current = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 3000))

        let shape = try exported(current)

        XCTAssertTrue(shape.contains("swap failed"))
        XCTAssertFalse(shape.contains("leftover"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftover.path))
    }

    func testOldSessionsGoWhenTheirTextOutgrowsTheUncompressedLimit() throws {
        let oldest = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        for index in 0 ..< 1000 {
            oldest.log(record("line \(index)"))
        }
        _ = try exported(oldest)
        let older = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 2000))
        older.log(record("kept"))
        _ = try exported(older)
        let current = SessionLogBackend(
            directory: directory,
            startedAt: Date(timeIntervalSince1970: 3000),
            uncompressedBudgetBytes: 20000
        )
        current.log(record("current"))

        XCTAssertEqual(try exported(current), [
            "===== session 1970-01-01T00:33:20.000Z =====",
            "<environment>",
            "kept",
            "===== session 1970-01-01T00:50:00.000Z =====",
            "<environment>",
            "current",
        ])
    }

    func testOldSessionsGoWhenTheirNumberOutgrowsTheSessionLimit() throws {
        for start in 1 ... 4 {
            let old = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: TimeInterval(start * 1000)))
            old.log(record("session \(start)"))
            _ = try exported(old)
        }
        let current = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 5000), maxSessions: 3)
        current.log(record("current"))

        XCTAssertEqual(try exported(current), [
            "===== session 1970-01-01T00:50:00.000Z =====",
            "<environment>",
            "session 3",
            "===== session 1970-01-01T01:06:40.000Z =====",
            "<environment>",
            "session 4",
            "===== session 1970-01-01T01:23:20.000Z =====",
            "<environment>",
            "current",
        ])
    }

    func testTheSessionsStayOutOfBackups() throws {
        let sessionLog = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        _ = try exported(sessionLog)

        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testExportedFilePutsTheDeviceHeaderAboveTheSessions() throws {
        let sessionLog = SessionLogBackend(directory: directory, startedAt: Date(timeIntervalSince1970: 1000))
        sessionLog.log(record("swap failed"))

        let url = try LogExporter.exportToTemporaryFile(sessionLog: sessionLog, filenamePrefix: "SessionLogBackendTests")
        let shape = try shape(of: String(contentsOf: url, encoding: .utf8))
        try FileManager.default.removeItem(at: url)

        XCTAssertEqual(shape.first, "=== Keeper Log Export ===")
        XCTAssertEqual(Array(shape.suffix(3)), [
            "===== session 1970-01-01T00:16:40.000Z =====",
            "<environment>",
            "swap failed",
        ])
    }

    private func record(_ message: String) -> LogRecord {
        LogRecord(
            timestamp: Date(timeIntervalSince1970: 1000),
            subsystem: "test",
            category: "test",
            severity: .info,
            message: message,
            file: "SessionLogBackendTests.swift",
            function: "test",
            line: 1
        )
    }

    private func exported(_ sessionLog: SessionLogBackend) throws -> [String] {
        let url = try LogExporter.exportToTemporaryFile(sessionLog: sessionLog, filenamePrefix: "SessionLogBackendTests")
        let text = try String(contentsOf: url, encoding: .utf8)
        try FileManager.default.removeItem(at: url)
        return Array(shape(of: text).drop { !$0.hasPrefix("===== session") })
    }

    private func shape(of export: String) -> [String] {
        export
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                if line.hasPrefix("app=") {
                    return "<environment>"
                }
                if let range = line.range(of: "[INFO] [test] ") {
                    return String(line[range.upperBound...])
                }
                return line
            }
    }
}
