import Darwin
import Foundation
import PerpsModels
import TKLogging

enum PerpsPendingJournalError: Error, Equatable {
    case missingPending(String)
    case missingFunding(String)
    case revisionMismatch(operationId: String, expected: Int, actual: Int)
    case identityChanged(String)
    case unsupportedVersion(Int)
    /// A funding record this build could not read was set aside. It may be a payment still
    /// on its way, so no new one is recorded while that evidence exists.
    case fundingSetAside
}

final class PerpsPendingJournal: Sendable {
    private struct Contents: Codable, Equatable {
        static let currentVersion = 2

        var version: Int
        var pending: [String: PerpsPendingTradingAction]
        var funding: [String: PerpsPendingFundingOperation]

        init(
            pending: [String: PerpsPendingTradingAction] = [:],
            funding: [String: PerpsPendingFundingOperation] = [:]
        ) {
            version = Self.currentVersion
            self.pending = pending
            self.funding = funding
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let storedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
            guard (0 ... Self.currentVersion).contains(storedVersion) else {
                throw PerpsPendingJournalError.unsupportedVersion(storedVersion)
            }
            version = Self.currentVersion
            pending = try container.decode(
                [String: PerpsPendingTradingAction].self,
                forKey: .pending
            )
            if storedVersion == 0 {
                funding = try container.decodeIfPresent(
                    [String: PerpsPendingFundingOperation].self,
                    forKey: .funding
                ) ?? [:]
            } else {
                funding = try container.decode([String: PerpsPendingFundingOperation].self, forKey: .funding)
            }
        }
    }

    // Several service instances may address the same wallet file. One process-wide
    // queue makes each read-modify-write transaction atomic across those instances.
    private static let ioQueue = DispatchQueue(label: "PerpsPendingJournal.io")
    private static let pendingRetentionMillis: Int64 = 24 * 60 * 60 * 1000
    private static let settlementGraceMillis: Int64 = 24 * 60 * 60 * 1000
    private static let stalledRetentionMillis: Int64 = 30 * 24 * 60 * 60 * 1000
    private let fileURL: URL
    private var setAsidePrefix: String {
        "\(fileURL.lastPathComponent).funding-unreadable"
    }

    init(
        walletId: String,
        environment: String,
        directoryURL: URL? = nil
    ) {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
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

    func savePendingIfAbsentWithStatus(
        _ pending: PerpsPendingTradingAction
    ) async throws -> (pending: PerpsPendingTradingAction, inserted: Bool) {
        try await mutate { contents in
            if let existing = contents.pending[pending.operationId] {
                return (existing, false)
            }
            contents.pending[pending.operationId] = pending
            return (pending, true)
        }
    }

    func appendSignedStep(
        operationId: String,
        step: PerpsPendingSignedStep,
        refs: [PerpsPendingOrderRef]
    ) async throws {
        try await mutate { contents in
            guard var pending = contents.pending[operationId] else {
                throw PerpsPendingJournalError.missingPending(operationId)
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
        }
    }

    func pending(operationId: String) async throws -> PerpsPendingTradingAction? {
        try await query { $0.pending[operationId] }
    }

    func removePending(operationId: String) async throws {
        try await mutate { contents in
            contents.pending.removeValue(forKey: operationId)
        }
    }

    func allPending() async throws -> [PerpsPendingTradingAction] {
        try await query { Array($0.pending.values) }
    }

    func saveFundingIfAbsent(
        _ operation: PerpsPendingFundingOperation
    ) async throws -> (operation: PerpsPendingFundingOperation, inserted: Bool) {
        try await mutate { contents in
            try self.requireFundingIntact()
            if let existing = contents.funding[operation.operationId] {
                return (existing, false)
            }
            contents.funding[operation.operationId] = operation
            return (operation, true)
        }
    }

    func funding(operationId: String) async throws -> PerpsPendingFundingOperation? {
        try await query { contents in
            try self.requireFundingIntact()
            return contents.funding[operationId]
        }
    }

    func allFunding() async throws -> [PerpsPendingFundingOperation] {
        try await query { contents in
            try self.requireFundingIntact()
            return Array(contents.funding.values)
        }
    }

    /// Applies `transform` inside the same read-modify-write transaction that checks the
    /// revision, so a stale caller cannot roll a newer stage back. Keep it a pure mutation:
    /// it runs on the journal's IO queue.
    func updateFunding(
        operationId: String,
        expectedRevision: Int,
        _ transform: @escaping @Sendable (inout PerpsPendingFundingOperation) throws -> Void
    ) async throws -> PerpsPendingFundingOperation {
        try await mutate { contents in
            guard let current = contents.funding[operationId] else {
                throw PerpsPendingJournalError.missingFunding(operationId)
            }
            guard current.revision == expectedRevision else {
                throw PerpsPendingJournalError.revisionMismatch(
                    operationId: operationId,
                    expected: expectedRevision,
                    actual: current.revision
                )
            }
            var updated = current
            try transform(&updated)
            guard updated.operationId == current.operationId,
                  updated.walletId == current.walletId,
                  updated.walletIdentity == current.walletIdentity,
                  updated.environment == current.environment,
                  updated.kind == current.kind
            else {
                throw PerpsPendingJournalError.identityChanged(operationId)
            }
            guard updated != current else { return current }
            updated.revision = current.revision + 1
            updated.updatedAtMillis = Self.nowMillis()
            contents.funding[operationId] = updated
            return updated
        }
    }

    func removeFunding(operationId: String, expectedRevision: Int? = nil) async throws {
        try await mutate { contents in
            guard let current = contents.funding[operationId] else { return }
            if let expectedRevision, current.revision != expectedRevision {
                throw PerpsPendingJournalError.revisionMismatch(
                    operationId: operationId,
                    expected: expectedRevision,
                    actual: current.revision
                )
            }
            contents.funding.removeValue(forKey: operationId)
        }
    }

    /// Drops pending journals the venue can no longer act on. Confirmation itself is
    /// tk-perps polling; this is only a backstop for abandoned files. An entry is kept
    /// while anything it holds can still reach the venue — a signed payload until its
    /// transaction expires, an order until it stops resting — plus a grace period,
    /// because dropping it earlier would forget an order that is still live and let a
    /// retry place a second one.
    @discardableResult
    func cleanupPending() async throws -> (funding: [PerpsPendingFundingOperation], fundingIntact: Bool) {
        try await mutate { contents in
            let now = Self.nowMillis()
            let cutoff = now - Self.pendingRetentionMillis
            let stalledCutoff = now - Self.stalledRetentionMillis
            contents.pending = contents.pending.filter { _, pending in
                let deadlines = (pending.signedSteps ?? []).map(\.transactionExpiryUnixMs)
                    + [pending.expiresAtMillis].compactMap { $0 }
                guard let deadline = deadlines.max() else {
                    return pending.createdAtMillis > cutoff
                }
                return now < deadline + Self.settlementGraceMillis
            }
            contents.funding = contents.funding.filter { _, operation in
                // A stalled record has no side left to reconcile against, so it is kept as
                // evidence rather than as pending work — and only until the evidence stops
                // being local: the transaction stays on L1 and the record stays on the
                // backend long after this file forgets it.
                if operation.isStalled { return operation.updatedAtMillis > stalledCutoff }
                // Same rule for money: only a draft or a settled record ages out.
                if operation.isUnresolved { return true }
                return operation.updatedAtMillis > cutoff
            }
            return (Array(contents.funding.values), (try? self.requireFundingIntact()) != nil)
        }
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func query<T>(_ body: @escaping @Sendable (Contents) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    try continuation.resume(returning: body(self.read()))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func mutate<T>(_ body: @escaping @Sendable (inout Contents) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            Self.ioQueue.async {
                do {
                    let contents = try self.read()
                    var updated = contents
                    let value = try body(&updated)
                    if updated != contents {
                        try self.write(updated)
                    }
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func read() throws -> Contents {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Contents() }
        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder().decode(Contents.self, from: data)
        } catch let error as PerpsPendingJournalError {
            throw error
        } catch {
            let salvaged = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap(Self.salvage)
            if let salvaged, !salvaged.lostFunding {
                Log.perps.w("pending journal partly unreadable — kept \(salvaged.contents.pending.count) trading records")
                return salvaged.contents
            }
            // A funding record lost here may be a payment still on its way. The document is
            // kept whole as evidence, which blocks new funding records while trading goes on
            // with whatever could be read.
            let evidenceURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("\(setAsidePrefix).\(UUID().uuidString)")
            if let salvaged {
                try FileManager.default.copyItem(at: fileURL, to: evidenceURL)
                try write(salvaged.contents)
            } else {
                try replaceItem(at: evidenceURL, with: fileURL)
            }
            Log.perps.w("pending journal funding unreadable — set aside at \(evidenceURL.lastPathComponent)")
            return salvaged?.contents ?? Contents()
        }
    }

    private func requireFundingIntact() throws {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: fileURL.deletingLastPathComponent().path)) ?? []
        guard !names.contains(where: { $0.hasPrefix(setAsidePrefix) }) else {
            throw PerpsPendingJournalError.fundingSetAside
        }
    }

    private static func salvage(_ root: [String: Any]) -> (contents: Contents, lostFunding: Bool)? {
        guard let pending = root["pending"] as? [String: Any] else { return nil }
        let storedVersion = root["version"] as? Int ?? 0
        let funding = root["funding"] as? [String: Any]
        let recoveredFunding: [String: PerpsPendingFundingOperation] = salvageRecords(funding ?? [:])
        let lostFunding = if let funding {
            recoveredFunding.count != funding.count
        } else {
            storedVersion != 0 || root["funding"] != nil
        }
        return (Contents(pending: salvageRecords(pending), funding: recoveredFunding), lostFunding)
    }

    private static func salvageRecords<T: Decodable>(_ records: [String: Any]) -> [String: T] {
        let decoder = JSONDecoder()
        return records.reduce(into: [String: T]()) { result, record in
            guard let payload = try? JSONSerialization.data(withJSONObject: record.value),
                  let decoded = try? decoder.decode(T.self, from: payload)
            else {
                return
            }
            result[record.key] = decoded
        }
    }

    private func write(_ contents: Contents) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
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
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }

        try data.write(to: temporaryURL, options: .completeFileProtectionUntilFirstUserAuthentication)
        try FileManager.default.setAttributes(
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

extension PerpsPendingJournal {
    func persistDepositStep(_ step: ChainKitSignedTransaction, operationId: String) async throws -> PerpsPendingFundingOperation {
        guard let current = try await funding(operationId: operationId) else {
            throw PerpsPendingJournalError.missingFunding(operationId)
        }
        return try await updateFunding(operationId: operationId, expectedRevision: current.revision) { stored in
            guard var deposit = stored.deposit, var transmission = deposit.transmission else {
                throw PerpsDepositServiceError.resumedPaymentChanged(operationId)
            }
            if let index = transmission.steps.firstIndex(where: { $0.payloadId == step.payloadId }) {
                guard transmission.steps[index].data == step.data else {
                    throw PerpsDepositServiceError.resumedPaymentChanged(operationId)
                }
                transmission.steps[index] = step
            } else {
                transmission.steps.append(step)
            }
            deposit.transmission = transmission
            if try step.payloadId == (transmission.operation.parsed()).payloads.last?.id {
                deposit.sourceTxHash = step.hash
                if step.acknowledged {
                    deposit.stage = deposit.depositId != nil ? .registeredPending
                        : deposit.registration == nil ? .needsAuthorization : .registrationPending
                }
            }
            stored.details = .deposit(deposit)
        }
    }
}
