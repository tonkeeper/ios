import Foundation
import os

public final class SessionLogBackend: LogBackend, @unchecked Sendable {
    private let directory: URL
    private let session: Int64
    private let segmentBytes: Int
    private let budgetBytes: Int
    private let uncompressedBudgetBytes: Int
    private let maxSessions: Int
    private let queue = DispatchQueue(label: "TKLogging.SessionLogBackend", qos: .utility)
    private let diagnostics = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TKLogging", category: "SessionLog")
    private var segment = 0
    private var segmentSize = 0
    private var handle: FileHandle?

    public init(
        directory: URL,
        startedAt: Date = Date(),
        segmentBytes: Int = 1024 * 1024,
        budgetBytes: Int = 10 * 1024 * 1024,
        uncompressedBudgetBytes: Int = 50 * 1024 * 1024,
        maxSessions: Int = 200
    ) {
        self.directory = directory
        session = Int64((startedAt.timeIntervalSince1970 * 1000).rounded())
        self.segmentBytes = segmentBytes
        self.budgetBytes = budgetBytes
        self.uncompressedBudgetBytes = uncompressedBudgetBytes
        self.maxSessions = maxSessions
        let environment = LogExporter.environmentDescription
        queue.async {
            self.prepareDirectory()
            self.appendInfo(environment)
            self.archiveFinishedSessions()
            self.prune()
        }
    }

    public func log(_ record: LogRecord) {
        queue.async {
            self.append(record.fileLine)
        }
    }

    public func writeSessions(to output: FileHandle) throws {
        try queue.sync {
            for (index, stored) in storedSessions().enumerated() {
                if index > 0 {
                    try output.write(contentsOf: Data("\n".utf8))
                }
                try autoreleasepool {
                    try export(stored, to: output)
                }
            }
        }
    }
}

public extension LoggingConfiguration {
    var sessionLog: SessionLogBackend? {
        backends.lazy.compactMap { $0 as? SessionLogBackend }.first
    }
}

private extension SessionLogBackend {
    struct StoredFile {
        let url: URL
        let size: Int
        let uncompressedSize: Int
    }

    struct StoredSegment {
        let index: Int
        let file: StoredFile
    }

    struct StoredSession {
        let id: Int64
        var info: StoredFile?
        var segments: [StoredSegment] = []
        var archive: StoredFile?

        var rawFiles: [StoredFile] {
            segments.map(\.file) + [info].compactMap { $0 }
        }

        var files: [StoredFile] {
            rawFiles + [archive].compactMap { $0 }
        }
    }

    var infoURL: URL {
        directory.appendingPathComponent("\(session).info")
    }

    var segmentURL: URL {
        directory.appendingPathComponent("\(session).\(segment).log")
    }

    func archiveURL(for id: Int64, uncompressedSize: Int) -> URL {
        directory.appendingPathComponent("\(id).\(uncompressedSize).lzfse")
    }

    func append(_ line: String) {
        let data = Data((line + "\n").utf8)
        if segmentSize > 0, segmentSize + data.count > segmentBytes {
            closeSegment()
            segment += 1
            prune()
        }
        guard let handle = openedSegment() else { return }
        do {
            try handle.write(contentsOf: data)
            segmentSize += data.count
        } catch {
            report("write \(segmentURL.lastPathComponent)", error)
        }
    }

    func appendInfo(_ line: String) {
        do {
            let handle = try openForAppending(infoURL)
            try handle.write(contentsOf: Data((line + "\n").utf8))
            try handle.close()
        } catch {
            report("write \(infoURL.lastPathComponent)", error)
        }
    }

    func openedSegment() -> FileHandle? {
        if let handle {
            return handle
        }
        do {
            let handle = try openForAppending(segmentURL)
            segmentSize = try Int(handle.offset())
            self.handle = handle
            return handle
        } catch {
            report("open \(segmentURL.lastPathComponent)", error)
            return nil
        }
    }

    func closeSegment() {
        guard let handle else { return }
        self.handle = nil
        segmentSize = 0
        do {
            try handle.close()
        } catch {
            report("close \(segmentURL.lastPathComponent)", error)
        }
    }

    func prepareDirectory() {
        var directory = directory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        } catch {
            report("prepare \(directory.lastPathComponent)", error)
        }
    }

    func openForAppending(_ url: URL) throws -> FileHandle {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        return handle
    }

    func archiveFinishedSessions() {
        for stored in storedSessions() where stored.id != session && !stored.rawFiles.isEmpty {
            autoreleasepool {
                if stored.archive == nil {
                    do {
                        var text = Data()
                        try render(stored) { text.append($0) }
                        let archive = try (text as NSData).compressed(using: .lzfse) as Data
                        try archive.write(to: archiveURL(for: stored.id, uncompressedSize: text.count), options: .atomic)
                    } catch {
                        report("archive session \(stored.id)", error)
                        return
                    }
                }
                stored.rawFiles.forEach { delete($0) }
            }
        }
    }

    func prune() {
        let sessions = storedSessions()
        var count = sessions.count
        var size = sessions.flatMap(\.files).reduce(0) { $0 + $1.size }
        var uncompressedSize = sessions.flatMap(\.files).reduce(0) { $0 + $1.uncompressedSize }
        func isOverSize() -> Bool {
            size > budgetBytes || uncompressedSize > uncompressedBudgetBytes
        }
        func isOverBudget() -> Bool {
            isOverSize() || count > maxSessions
        }
        func remove(_ file: StoredFile) {
            guard delete(file) else { return }
            size -= file.size
            uncompressedSize -= file.uncompressedSize
        }
        for stored in sessions where isOverBudget() {
            if stored.id == session {
                for part in stored.segments where part.index != segment && isOverSize() {
                    remove(part.file)
                }
            } else {
                stored.files.forEach(remove)
                count -= 1
            }
        }
    }

    @discardableResult
    func delete(_ file: StoredFile) -> Bool {
        do {
            try FileManager.default.removeItem(at: file.url)
            return true
        } catch {
            report("remove \(file.url.lastPathComponent)", error)
            return false
        }
    }

    func storedSessions() -> [StoredSession] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        } catch {
            report("list \(directory.lastPathComponent)", error)
            return []
        }
        var sessions: [Int64: StoredSession] = [:]
        for url in urls {
            let base = url.deletingPathExtension()
            switch url.pathExtension {
            case "info":
                guard let id = Int64(base.lastPathComponent) else { continue }
                sessions[id, default: StoredSession(id: id)].info = storedFile(url)
            case "log":
                guard let index = Int(base.pathExtension),
                      let id = Int64(base.deletingPathExtension().lastPathComponent)
                else { continue }
                sessions[id, default: StoredSession(id: id)].segments.append(
                    StoredSegment(index: index, file: storedFile(url))
                )
            case "lzfse":
                guard let uncompressedSize = Int(base.pathExtension),
                      let id = Int64(base.deletingPathExtension().lastPathComponent)
                else { continue }
                sessions[id, default: StoredSession(id: id)].archive = storedFile(url, uncompressedSize: uncompressedSize)
            default:
                continue
            }
        }
        return sessions.values
            .sorted { $0.id < $1.id }
            .map { stored in
                var stored = stored
                stored.segments.sort { $0.index < $1.index }
                return stored
            }
    }

    func storedFile(_ url: URL, uncompressedSize: Int? = nil) -> StoredFile {
        let size: Int
        do {
            size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        } catch {
            report("size \(url.lastPathComponent)", error)
            size = 0
        }
        return StoredFile(url: url, size: size, uncompressedSize: uncompressedSize ?? size)
    }

    func export(_ stored: StoredSession, to output: FileHandle) throws {
        var started = false
        do {
            try render(stored) { data in
                started = true
                try output.write(contentsOf: data)
            }
        } catch {
            report("export session \(stored.id)", error)
            let note = line("--- this session could not be read: \(error.localizedDescription)")
            try output.write(contentsOf: started ? note : line(marker(for: stored)) + note)
        }
    }

    func render(_ stored: StoredSession, into sink: (Data) throws -> Void) throws {
        if let archive = stored.archive {
            try sink((Data(contentsOf: archive.url) as NSData).decompressed(using: .lzfse) as Data)
            return
        }
        try sink(line(marker(for: stored)))
        if let info = stored.info {
            try sink(terminated(Data(contentsOf: info.url)))
        }
        if let first = stored.segments.first, first.index > 0 {
            try sink(line("--- earlier records of this session were removed to stay within the size limit"))
        }
        for part in stored.segments {
            try sink(terminated(Data(contentsOf: part.file.url)))
        }
    }

    func marker(for stored: StoredSession) -> String {
        let startedAt = Date(timeIntervalSince1970: TimeInterval(stored.id) / 1000)
        return "===== session \(LogTimestamp.formatter.string(from: startedAt)) ====="
    }

    func line(_ text: String) -> Data {
        Data((text + "\n").utf8)
    }

    func terminated(_ data: Data) -> Data {
        guard let last = data.last, last != UInt8(ascii: "\n") else { return data }
        return data + Data("\n".utf8)
    }

    func report(_ operation: String, _ error: any Error) {
        diagnostics.error("session log: cannot \(operation, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}

private extension LogRecord {
    var fileLine: String {
        "\(LogTimestamp.formatter.string(from: timestamp)) [\(severity.name)] [\(category)] \(OSLogBackend.message(for: self))"
    }
}
