import ChainKit
import Darwin
import Foundation

final class PerpsClientOrderIndexAllocator: @unchecked Sendable {
    private struct Contents: Codable {
        let last: Int64
    }

    private enum AllocationError: Error {
        case exhausted
        case invalidPersistedValue
    }

    private let lock = NSLock()
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

    func next(nowUnixMs: Int64) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }

        let minimum = LighterConstants.shared.MinClientOrderIndex
        let maximum = LighterConstants.shared.MaxClientOrderIndex
        let persisted = try read()
        let previous = max(last ?? minimum - 1, persisted ?? minimum - 1)
        guard previous >= minimum - 1, previous < maximum else {
            throw AllocationError.invalidPersistedValue
        }
        let candidate = max(nowUnixMs % maximum, minimum)
        let next = max(candidate, previous + 1)
        guard next < maximum else { throw AllocationError.exhausted }
        try write(Contents(last: next))
        last = next
        return next
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
