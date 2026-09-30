import Darwin
import Foundation

final class PerpsPendingJournal: @unchecked Sendable {
    private struct Contents: Codable {
        var pending = [String: PerpsPendingTradingAction]()

        init(pending: [String: PerpsPendingTradingAction] = [:]) {
            self.pending = pending
        }
    }

    private enum StoreError: Error {
        case missingPending(String)
    }

    // Several service instances may address the same wallet file. One process-wide
    // queue makes each read-modify-write transaction atomic across those instances.
    private static let ioQueue = DispatchQueue(label: "PerpsPendingJournal.io")
    private static let pendingRetentionMillis: Int64 = 24 * 60 * 60 * 1000
    private static let settlementGraceMillis: Int64 = 24 * 60 * 60 * 1000
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

    func savePendingIfAbsent(_ pending: PerpsPendingTradingAction) async throws -> PerpsPendingTradingAction {
        try await savePendingIfAbsentWithStatus(pending).pending
    }

    func savePendingIfAbsentWithStatus(
        _ pending: PerpsPendingTradingAction
    ) async throws -> (pending: PerpsPendingTradingAction, inserted: Bool) {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    if let existing = contents.pending[pending.operationId] {
                        continuation.resume(returning: (existing, false))
                        return
                    }
                    contents.pending[pending.operationId] = pending
                    try self.write(contents)
                    continuation.resume(returning: (pending, true))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func appendOrderRefs(operationId: String, refs: [PerpsPendingOrderRef]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    guard var pending = contents.pending[operationId] else {
                        throw StoreError.missingPending(operationId)
                    }
                    var orderRefs = pending.orderRefs ?? []
                    for ref in refs where !orderRefs.contains(ref) {
                        orderRefs.append(ref)
                    }
                    pending.orderRefs = orderRefs
                    contents.pending[operationId] = pending
                    try self.write(contents)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func appendSignedStep(
        operationId: String,
        step: PerpsPendingSignedStep,
        refs: [PerpsPendingOrderRef]
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    guard var pending = contents.pending[operationId] else {
                        throw StoreError.missingPending(operationId)
                    }
                    var steps = pending.signedSteps ?? []
                    if let index = steps.firstIndex(where: { $0.stepId == step.stepId }) {
                        steps[index] = step
                    } else {
                        steps.append(step)
                    }
                    pending.signedSteps = steps
                    var orderRefs = pending.orderRefs ?? []
                    for ref in refs where !orderRefs.contains(ref) {
                        orderRefs.append(ref)
                    }
                    pending.orderRefs = orderRefs
                    contents.pending[operationId] = pending
                    try self.write(contents)
                    continuation.resume()
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

    func allPending() async throws -> [PerpsPendingTradingAction] {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    try continuation.resume(returning: Array(self.read().pending.values))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Drops pending journals the venue can no longer act on. Confirmation itself is
    /// tk-perps polling; this is only a backstop for abandoned files. An operation that
    /// can leave an order resting is kept until that order's expiry plus a grace period,
    /// because dropping it earlier would forget an order that is still live and let a
    /// retry place a second one.
    func cleanupPending() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    var contents = try self.read()
                    let now = Int64(Date().timeIntervalSince1970 * 1000)
                    let cutoff = now - Self.pendingRetentionMillis
                    let oldCount = contents.pending.count
                    contents.pending = contents.pending.filter { _, pending in
                        // A signed payload is evidence that the venue may already have
                        // accepted a side effect. Never age it out before reconciliation;
                        // dropping it would make a retry capable of duplicating the order.
                        if pending.signedSteps?.isEmpty == false { return true }
                        guard let expiresAtMillis = pending.expiresAtMillis else {
                            return pending.createdAtMillis > cutoff
                        }
                        return now < expiresAtMillis + Self.settlementGraceMillis
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
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Contents.self, from: data)
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
}
