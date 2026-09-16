import Foundation
import TKKeychain
import TKLogging

/// Wallet ids whose binding still has to be detached. Written before the request leaves, so a
/// wallet deleted right before termination is still unregistered on a later launch.
final class MultichainPendingUnregisterStore: @unchecked Sendable {
    private let keychainVault: TKKeychainVault
    private let fallbackDefaults: UserDefaults
    private let lock = NSLock()

    init(
        keychainVault: TKKeychainVault,
        fallbackDefaults: UserDefaults = .standard
    ) {
        self.keychainVault = keychainVault
        self.fallbackDefaults = fallbackDefaults
    }

    func load() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(stored()).sorted()
    }

    func add(_ walletIds: [String]) {
        guard !walletIds.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        mutateJournal { journal in
            journal.removals.subtract(walletIds)
            journal.additions.formUnion(walletIds)
        }
    }

    func remove(_ walletIds: [String]) {
        guard !walletIds.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        mutateJournal { journal in
            journal.additions.subtract(walletIds)
            journal.removals.formUnion(walletIds)
        }
    }
}

private extension MultichainPendingUnregisterStore {
    struct Journal: Codable {
        var additions = Set<String>()
        var removals = Set<String>()

        var isEmpty: Bool {
            additions.isEmpty && removals.isEmpty
        }

        func applying(to stored: Set<String>) -> Set<String> {
            stored.subtracting(removals).union(additions)
        }
    }

    static let fallbackKey = "multichain_pending_unregister_journal"

    func stored() -> Set<String> {
        let journal = loadJournal()
        guard let stored = loadStored() else {
            // The complete Keychain snapshot is temporarily unavailable. Additions are safe to
            // retry immediately; removals are applied once the snapshot can be read again.
            return journal.additions
        }
        let intended = journal.applying(to: stored)
        if !journal.isEmpty, writeStored(intended) {
            saveJournal(Journal())
        }
        return intended
    }

    func mutateJournal(_ mutation: (inout Journal) -> Void) {
        var journal = loadJournal()
        mutation(&journal)
        // Write-ahead fallback: if the Keychain read or write below fails, a new process can still
        // replay the exact additions/removals against the last durable snapshot.
        saveJournal(journal)

        guard let stored = loadStored() else { return }
        if writeStored(journal.applying(to: stored)) {
            saveJournal(Journal())
        }
    }

    func loadStored() -> Set<String>? {
        do {
            let walletIds: [String] = try keychainVault.get(query: query)
            return Set(walletIds)
        } catch TKKeychainError.noItem {
            return []
        } catch TKKeychainVaultError.unexpectedData {
            Log.w("🪵 Multichain: pending unregisters contain unexpected data")
            return nil
        } catch {
            Log.w("🪵 Multichain: load pending unregisters failed", error: error)
            return nil
        }
    }

    func writeStored(_ walletIds: Set<String>) -> Bool {
        do {
            if walletIds.isEmpty {
                try keychainVault.delete(query)
            } else {
                try keychainVault.set(Array(walletIds).sorted(), query: query)
            }
            return true
        } catch TKKeychainError.noItem {
            return true
        } catch {
            Log.w("🪵 Multichain: save pending unregisters failed", error: error)
            return false
        }
    }

    func loadJournal() -> Journal {
        guard let data = fallbackDefaults.data(forKey: Self.fallbackKey) else {
            return Journal()
        }
        do {
            return try JSONDecoder().decode(Journal.self, from: data)
        } catch {
            Log.w("🪵 Multichain: load pending unregister journal failed", error: error)
            return Journal()
        }
    }

    func saveJournal(_ journal: Journal) {
        guard !journal.isEmpty else {
            fallbackDefaults.removeObject(forKey: Self.fallbackKey)
            flushJournal()
            return
        }
        do {
            try fallbackDefaults.set(JSONEncoder().encode(journal), forKey: Self.fallbackKey)
            flushJournal()
        } catch {
            Log.w("🪵 Multichain: save pending unregister journal failed", error: error)
        }
    }

    func flushJournal() {
        // The journal is the fallback specifically for termination between wallet deletion and the
        // network request, so unlike ordinary preferences it must be flushed before returning.
        guard fallbackDefaults.synchronize() else {
            Log.w("🪵 Multichain: flush pending unregister journal failed")
            return
        }
    }

    var query: TKKeychainQuery {
        TKKeychainQuery(
            item: .genericPassword(service: "MultichainPendingUnregister", account: "device"),
            accessGroup: nil,
            biometry: .none,
            accessible: .afterFirstUnlockThisDeviceOnly
        )
    }
}
