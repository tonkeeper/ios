import ChainKit
import Darwin
import Foundation

final class LighterOperationFileStore: NSObject, LighterOperationStore, @unchecked Sendable {
    private struct Contents: Codable {
        var version = 1
        var operations = [String: String]()
        var pending = [String: PerpsPendingTradingAction]()
    }

    private enum StoreError: Error {
        case unsupportedVersion(Int)
    }

    // Several service instances may address the same wallet file. One process-wide
    // queue makes each read-modify-write transaction atomic across those instances.
    private static let ioQueue = DispatchQueue(label: "LighterOperationFileStore.io")
    private static let terminalRetentionLimit = 100
    private static let orphanPendingGraceMillis: Int64 = 60000
    private let fileManager: FileManager
    private let fileURL: URL

    init(
        walletId: String,
        environment: String,
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = directoryURL
            ?? applicationSupport.appendingPathComponent("LighterOperations", isDirectory: true)
        let scope = Data("\(walletId)/\(environment)".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        fileURL = directory.appendingPathComponent("\(scope).json")
    }

    func load(
        accountIndex: Int64,
        apiKeyIndex: Int32,
        completionHandler: @escaping ([LighterOperation]?, Error?) -> Void
    ) {
        Self.ioQueue.async {
            do {
                let operations = try self.read().operations.values
                    .map { try LighterOperationCodec.shared.decode(value: $0) }
                    .filter { $0.accountIndex == accountIndex && $0.apiKeyIndex == apiKeyIndex }
                    .sorted { $0.createdAtMillis < $1.createdAtMillis }
                completionHandler(operations, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    func save(operation: LighterOperation, completionHandler: @escaping (Error?) -> Void) {
        Self.ioQueue.async {
            do {
                var contents = try self.read()
                contents.operations[self.key(
                    accountIndex: operation.accountIndex,
                    apiKeyIndex: operation.apiKeyIndex,
                    operationId: operation.operationId
                )] = try LighterOperationCodec.shared.encode(operation: operation)
                try self.pruneTerminalOperations(&contents)
                try self.write(contents)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func remove(
        accountIndex: Int64,
        apiKeyIndex: Int32,
        operationId: String,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Self.ioQueue.async {
            do {
                var contents = try self.read()
                contents.operations.removeValue(forKey: self.key(
                    accountIndex: accountIndex,
                    apiKeyIndex: apiKeyIndex,
                    operationId: operationId
                ))
                try self.write(contents)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func savePendingIfAbsent(_ pending: PerpsPendingTradingAction) async throws -> PerpsPendingTradingAction {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    if let existing = contents.pending[pending.operationId] {
                        continuation.resume(returning: existing)
                        return
                    }
                    contents.pending[pending.operationId] = pending
                    try self.write(contents)
                    continuation.resume(returning: pending)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func pending(operationId: String) async throws -> PerpsPendingTradingAction? {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    try continuation.resume(returning: self.read().pending[operationId])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removePending(operationId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    contents.pending.removeValue(forKey: operationId)
                    try self.write(contents)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Clears app-side baselines after their SDK operation became terminal, and
    /// baselines left behind when the process died before the SDK journal write.
    func cleanupPending() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    let operations = try contents.operations.values.map {
                        try LighterOperationCodec.shared.decode(value: $0)
                    }
                    let unresolvedIds = Set(operations.filter { !$0.isTerminal }.map(\.operationId))
                    let knownIds = Set(operations.map(\.operationId))
                    let cutoff = Int64(Date().timeIntervalSince1970 * 1000)
                        - Self.orphanPendingGraceMillis
                    let oldCount = contents.pending.count
                    contents.pending = contents.pending.filter { operationId, pending in
                        unresolvedIds.contains(operationId)
                            || (!knownIds.contains(operationId) && pending.createdAtMillis > cutoff)
                    }
                    if contents.pending.count != oldCount {
                        try self.write(contents)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func read() throws -> Contents {
        guard fileManager.fileExists(atPath: fileURL.path) else { return Contents() }
        let contents = try JSONDecoder().decode(Contents.self, from: Data(contentsOf: fileURL))
        guard contents.version == 1 else { throw StoreError.unsupportedVersion(contents.version) }
        return contents
    }

    private func write(_ contents: Contents) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(contents)
        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        var shouldRemoveTemporary = true
        defer {
            if shouldRemoveTemporary {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        try data.write(to: temporaryURL, options: .completeFileProtectionUntilFirstUserAuthentication)
        try fileManager.setAttributes(
            [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                .posixPermissions: 0o600,
            ],
            ofItemAtPath: temporaryURL.path
        )
        try synchronizeFile(at: temporaryURL)
        try replaceItem(at: fileURL, with: temporaryURL)
        shouldRemoveTemporary = false
        try synchronizeFile(at: fileURL)
        try synchronizeFile(at: directoryURL)
    }

    private func synchronizeFile(at url: URL) throws {
        let descriptor = url.path.withCString { Darwin.open($0, O_RDONLY) }
        guard descriptor >= 0 else { throw makePOSIXError() }
        defer { Darwin.close(descriptor) }

        if Darwin.fcntl(descriptor, F_FULLFSYNC) == -1 {
            let fullSyncError = errno
            guard fullSyncError == EINVAL || fullSyncError == ENOTSUP else {
                throw makePOSIXError(fullSyncError)
            }
            guard Darwin.fsync(descriptor) == 0 else { throw makePOSIXError() }
        }
    }

    private func replaceItem(at destinationURL: URL, with sourceURL: URL) throws {
        let result = sourceURL.path.withCString { sourcePath in
            destinationURL.path.withCString { destinationPath in
                Darwin.rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else { throw makePOSIXError() }
    }

    private func makePOSIXError(_ rawCode: Int32 = errno) -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: rawCode) ?? .EIO)
    }

    private func pruneTerminalOperations(_ contents: inout Contents) throws {
        let terminal = try contents.operations.compactMap { key, value -> (String, LighterOperation)? in
            let operation = try LighterOperationCodec.shared.decode(value: value)
            return operation.isTerminal ? (key, operation) : nil
        }
        guard terminal.count > Self.terminalRetentionLimit else { return }
        for (key, operation) in terminal
            .sorted(by: { $0.1.updatedAtMillis > $1.1.updatedAtMillis })
            .dropFirst(Self.terminalRetentionLimit)
        {
            contents.operations.removeValue(forKey: key)
            contents.pending.removeValue(forKey: operation.operationId)
        }
    }

    private func key(accountIndex: Int64, apiKeyIndex: Int32, operationId: String) -> String {
        "\(accountIndex)/\(apiKeyIndex)/\(operationId)"
    }
}
