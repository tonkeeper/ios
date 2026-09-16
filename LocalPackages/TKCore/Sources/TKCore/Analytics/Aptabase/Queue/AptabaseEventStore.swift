import Foundation

/// Durable FIFO of pending analytics events.
actor AptabaseEventStore {
    struct Configuration {
        var directory: URL
        var fileName = "aptabase_events.jsonl"
        var maximumEventCount = 1000
        var maximumByteCount = 1024 * 1024
        /// The ingestion API drops anything older than 24h.
        var timeToLive: TimeInterval = 23 * 60 * 60

        static func `default`(fileManager: FileManager = .default) -> Configuration {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
            return Configuration(directory: applicationSupport.appendingPathComponent("Analytics", isDirectory: true))
        }
    }

    struct Batch {
        let events: [AptabaseEvent]
        let upperBound: Int
    }

    private struct Entry {
        let event: AptabaseEvent
        /// Encoded form kept alongside the event so rewriting the file never re-encodes.
        let line: Data
    }

    private static let newline = UInt8(ascii: "\n")

    private let configuration: Configuration
    private let fileManager: FileManager
    private let currentDate: @Sendable () -> Date

    private var entries = [Entry]()
    private var byteCount = 0
    private var isLoaded = false
    /// Absolute position of `entries[0]`. Entries only ever leave from the front, so this is enough
    /// to name a batch independently of what the queue did meanwhile.
    private var removedCount = 0

    private(set) var droppedCount = 0

    init(
        configuration: Configuration,
        fileManager: FileManager = .default,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.currentDate = currentDate
    }

    var count: Int {
        load()
        return entries.count
    }

    func load() {
        guard !isLoaded else { return }
        isLoaded = true
        prepareDirectory()
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = data.split(separator: Self.newline, omittingEmptySubsequences: true).compactMap { line in
            var line = Data(line)
            guard let event = try? AptabaseCoding.storageDecoder.decode(AptabaseEvent.self, from: line) else {
                return nil
            }
            line.append(Self.newline)
            return Entry(event: event, line: line)
        }
        byteCount = entries.reduce(0) { $0 + $1.line.count }
        prune()
        rewrite()
    }

    func append(_ event: AptabaseEvent) {
        load()
        guard var line = try? AptabaseCoding.storageEncoder.encode(event) else { return }
        line.append(Self.newline)
        entries.append(Entry(event: event, line: line))
        byteCount += line.count
        if prune() {
            rewrite()
        } else {
            appendToFile(line)
        }
    }

    func peek(limit: Int) -> Batch {
        load()
        if pruneExpired() {
            rewrite()
        }
        let events = entries.prefix(limit).map(\.event)
        return Batch(events: events, upperBound: removedCount + events.count)
    }

    func remove(upTo upperBound: Int) {
        let count = min(max(0, upperBound - removedCount), entries.count)
        guard count > 0 else { return }
        dropFirst(count)
        rewrite()
    }

    /// Drops a queue left behind by a run that had the persistent cache enabled. Without this, turning
    /// the feature flag off would strand those events on disk with nothing left to send them.
    static func purge(configuration: Configuration, fileManager: FileManager = .default) {
        let fileURL = configuration.directory.appendingPathComponent(configuration.fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }
}

private extension AptabaseEventStore {
    var fileURL: URL {
        configuration.directory.appendingPathComponent(configuration.fileName)
    }

    @discardableResult
    func prune() -> Bool {
        var didDrop = pruneExpired()
        while entries.count > configuration.maximumEventCount || byteCount > configuration.maximumByteCount {
            guard !entries.isEmpty else { break }
            dropFirst(1)
            droppedCount += 1
            didDrop = true
        }
        return didDrop
    }

    /// Drops a prefix rather than filtering, so `removedCount` stays a meaningful position even if the
    /// clock jumped backwards and left an old timestamp in the middle of the queue.
    func pruneExpired() -> Bool {
        let deadline = currentDate().addingTimeInterval(-configuration.timeToLive)
        let expired = entries.prefix { $0.event.timestamp < deadline }.count
        guard expired > 0 else { return false }
        dropFirst(expired)
        droppedCount += expired
        return true
    }

    func dropFirst(_ count: Int) {
        byteCount -= entries.prefix(count).reduce(0) { $0 + $1.line.count }
        entries.removeFirst(count)
        removedCount += count
    }

    func prepareDirectory() {
        guard !fileManager.fileExists(atPath: configuration.directory.path) else { return }
        try? fileManager.createDirectory(at: configuration.directory, withIntermediateDirectories: true)
        var directory = configuration.directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }

    func rewrite() {
        prepareDirectory()
        var data = Data()
        data.reserveCapacity(byteCount)
        for entry in entries {
            data.append(entry.line)
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    func appendToFile(_ line: Data) {
        prepareDirectory()
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }
}
