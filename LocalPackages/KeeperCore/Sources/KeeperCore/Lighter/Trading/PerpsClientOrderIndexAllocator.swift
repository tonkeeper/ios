import ChainKit
import Darwin
import Foundation

/// The client order indices one plan hands out: the order itself, then its auto-close legs.
struct PerpsClientOrderIndices: Equatable {
    static let count: Int64 = 3

    let order: Int64
    let takeProfit: Int64
    let stopLoss: Int64

    init(first: Int64) {
        order = first
        takeProfit = first + 1
        stopLoss = first + 2
    }
}

final class PerpsClientOrderIndexAllocator: @unchecked Sendable {
    private struct Contents: Codable {
        let last: Int64
    }

    private enum AllocationError: Error {
        case exhausted
    }

    // A reservation ends in `F_FULLFSYNC`, which must not hold a cooperative thread. The queue
    // is also the only place `last` is read or written.
    private let queue = DispatchQueue(label: "PerpsClientOrderIndexAllocator.io")
    private let fileManager: FileManager
    private let fileURL: URL
    private var last: Int64?

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = directoryURL
            ?? applicationSupport.appendingPathComponent("LighterOperations", isDirectory: true)
        fileURL = directory.appendingPathComponent("client-order-index.json")
    }

    func reserve(nowUnixMs: Int64) async throws -> PerpsClientOrderIndices {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try self.reserveOnQueue(nowUnixMs: nowUnixMs) })
            }
        }
    }

    private func reserveOnQueue(nowUnixMs: Int64) throws -> PerpsClientOrderIndices {
        let minimum = LighterConstants.shared.MinClientOrderIndex
        let maximum = LighterConstants.shared.MaxClientOrderIndex
        // A file that cannot be read, or holds a number outside the protocol's range,
        // is no worse than no file: the clock alone already answers above every index
        // handed out before now, and the planner refuses an index a live order already answers for.
        let persisted = ((try? read()) ?? nil).flatMap { ($0 >= minimum && $0 < maximum) ? $0 : nil }
        let previous = max(last ?? minimum - 1, persisted ?? minimum - 1)
        let candidate = max(nowUnixMs % maximum, minimum)
        let first = max(candidate, previous + 1)
        let lastReserved = first + PerpsClientOrderIndices.count - 1
        guard lastReserved < maximum else { throw AllocationError.exhausted }
        try write(Contents(last: lastReserved))
        last = lastReserved
        return PerpsClientOrderIndices(first: first)
    }

    private func read() throws -> Int64? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(Contents.self, from: Data(contentsOf: fileURL)).last
    }

    private func write(_ contents: Contents) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporary) }
        let data = try JSONEncoder().encode(contents)
        try data.write(to: temporary, options: .completeFileProtectionUntilFirstUserAuthentication)
        try fileManager.setAttributes(
            [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                .posixPermissions: 0o600,
            ],
            ofItemAtPath: temporary.path
        )
        try synchronize(temporary)
        let result = temporary.path.withCString { source in
            fileURL.path.withCString { destination in Darwin.rename(source, destination) }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        try synchronize(fileURL)
        try synchronize(directory)
    }

    private func synchronize(_ url: URL) throws {
        let descriptor = url.path.withCString { Darwin.open($0, O_RDONLY) }
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        if Darwin.fcntl(descriptor, F_FULLFSYNC) == -1 {
            let error = errno
            guard error == EINVAL || error == ENOTSUP else {
                throw POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO)
            }
            guard Darwin.fsync(descriptor) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }
}
