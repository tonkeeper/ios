import CryptoKit
import CryptoSwift
import Foundation
import TKKeychain
import TKLogging
import TonSwift
import TweetNacl

public struct MnemonicsVault {
    public struct MnemonicItem: Codable {
        public let identifier: String
        public let mnemonic: String
    }

    public enum Error: Swift.Error {
        case mnemonicsCorrupted
        case noMnemonic
        case other(Swift.Error)
    }

    private let keychainVault: TKKeychainVault
    private let seedProvider: () -> String
    private let logger = LogDomain.mnemonicStorage

    public init(
        keychainVault: TKKeychainVault,
        seedProvider: @escaping () -> String
    ) {
        self.keychainVault = keychainVault
        self.seedProvider = seedProvider
    }

    public func hasMnemonics() -> Bool {
        do {
            _ = try loadEncryptedMnemonics()
            return true
        } catch {
            return false
        }
    }

    public func addMnemonic(
        _ mnemonic: Mnemonic,
        identifier: MnemonicIdentifier,
        password: String
    ) async throws {
        do {
            let encryptedMnemonics = try loadEncryptedMnemonics()
            var mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
            mnemonics[identifier] = mnemonic
            let encryptedUpdatedMnemonics = try await encryptMnemonics(mnemonics, password: password)
            try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
        } catch {
            let mnemonics = [identifier: mnemonic]
            let encryptedMnemonics = try await encryptMnemonics(mnemonics, password: password)
            try saveEncryptedMnemonics(encryptedMnemonics)
        }
    }

    public func addMnemonics(_ mnemonics: Mnemonics, password: String) async throws {
        do {
            let encryptedMnemonics = try loadEncryptedMnemonics()
            var decryptedMnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
            decryptedMnemonics.merge(mnemonics, uniquingKeysWith: { $1 })
            let encryptedUpdatedMnemonics = try await encryptMnemonics(decryptedMnemonics, password: password)
            try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
        } catch {
            let encryptedMnemonics = try await encryptMnemonics(mnemonics, password: password)
            try saveEncryptedMnemonics(encryptedMnemonics)
        }
    }

    public func getMnemonic(
        identifier: MnemonicIdentifier,
        password: String
    ) async throws -> Mnemonic {
        let encryptedMnemonics = try loadEncryptedMnemonics()
        let mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
        guard let mnemonic = mnemonics[identifier] else {
            throw Error.noMnemonic
        }
        return mnemonic
    }

    public func deleteMnemonic(
        identifier: MnemonicIdentifier,
        password: String
    ) async throws {
        let encryptedMnemonics = try loadEncryptedMnemonics()
        var mnemonics = try await decryptMnemonics(encryptedMnemonics, password: password)
        mnemonics[identifier] = nil
        let encryptedUpdatedMnemonics = try await encryptMnemonics(mnemonics, password: password)
        try saveEncryptedMnemonics(encryptedUpdatedMnemonics)
    }

    public func deleteAll() async throws {
        try keychainVault.delete(getMnemonicsVaultQuery())
        try deletePassword()
    }

    public func changePassword(
        oldPassword: String,
        newPassword: String
    ) async throws {
        let encryptedMnemonics = try loadEncryptedMnemonics()
        let decryptedMnemonics = try await decryptMnemonics(encryptedMnemonics, password: oldPassword)
        let reencryptedMnemonics = try await encryptMnemonics(decryptedMnemonics, password: newPassword)
        try saveEncryptedMnemonics(reencryptedMnemonics)
    }

    public func validatePassword(_ password: String) async throws {
        let encryptedMnemonics = try loadEncryptedMnemonics()
        _ = try await decryptMnemonics(encryptedMnemonics, password: password)
    }

    public func importEncryptedMnemonics(_ encryptedMnemonics: EncryptedMnemonics) throws {
        try saveEncryptedMnemonics(encryptedMnemonics)
    }

    public func savePassword(_ password: String) throws {
        try keychainVault.recreateItem(password, query: getPasswordQuery())
        // Mark that the password item now uses biometryCurrentSet, so the unlock
        // path stops forcing the one-time biometryAny → biometryCurrentSet re-save.
        // Best-effort: the password is already saved, so a marker write failure
        // only costs one extra (idempotent) re-save on the next unlock.
        do {
            try keychainVault.set(Data([1]), query: getBiometryMigratedMarkerQuery())
        } catch {
            logger.e("🪵 failed to write biometry-migrated marker: \(error)")
        }
    }

    public func hasPassword() -> Bool {
        do {
            return try keychainVault.exists(query: getPasswordQuery())
        } catch {
            logger.e("🪵 native password presence check failed: \(error)")
            return false
        }
    }

    /// Whether the password item is known to use the `biometryCurrentSet` access
    /// control. The marker is written by `savePassword`; its absence means a
    /// legacy `biometryAny` item still needs the one-time migration, performed by
    /// re-saving the password on the next successful unlock.
    public func isBiometryItemMigrated() -> Bool {
        do {
            return try keychainVault.exists(query: getBiometryMigratedMarkerQuery())
        } catch {
            // Be conservative: an unexpected error must not strand a legacy
            // biometryAny item unmigrated, so report not-migrated and let the
            // unlock path re-save it with biometryCurrentSet.
            return false
        }
    }

    /// Non-interactive probe of the biometry-protected password item, so a failed
    /// biometric unlock can tell an invalidated enrolled set (recoverable by
    /// re-saving after a passcode entry) apart from a plain absent item.
    public func probeBiometryAccess() -> TKKeychainBiometryAccess {
        keychainVault.biometricAccessState(query: getPasswordQuery())
    }

    public func getPassword() throws -> String {
        let query = getPasswordQuery()
        return try keychainVault.get(query: query)
    }

    public func deletePassword() throws {
        // The marker must never outlive the password item: a marker left behind
        // makes an absent cache look like one invalidated by an enrollment change.
        // Deleting an already-absent password item throws, so run this regardless.
        defer {
            do {
                try keychainVault.delete(getBiometryMigratedMarkerQuery())
            } catch TKKeychainError.noItem {
            } catch {
                logger.e("🪵 failed to remove biometry-migrated marker: \(error)")
            }
        }
        try keychainVault.delete(getPasswordQuery())
    }

    public func getMnemonics(password: String) async throws -> Mnemonics {
        let encryptedMnemonics = try loadEncryptedMnemonics()
        return try await decryptMnemonics(encryptedMnemonics, password: password)
    }
}

private extension MnemonicsVault {
    func getChunksCountQuery() -> TKKeychainQuery {
        let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
        return TKKeychainQuery(
            item: .genericPassword(service: service, account: .encryptedMnemonicsChunksCountKey),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlocked
        )
    }

    func getChunkQuery(index: Int) -> TKKeychainQuery {
        let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
        let key = "\(String.encryptedMnemonicsChunkKey)\(index)"
        return TKKeychainQuery(
            item: .genericPassword(service: service, account: key),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlocked
        )
    }

    func getMnemonicsVaultQuery() -> TKKeychainQuery {
        let service = "\(String.mnemonicsVaultKey)_\(seedProvider())"
        return TKKeychainQuery(
            item: .genericPassword(service: service, account: nil),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }

    /// Non-biometric marker recording that the password item uses
    /// `biometryCurrentSet`. Shares the password's service so it lives in the same
    /// keychain domain; it holds no secret.
    func getBiometryMigratedMarkerQuery() -> TKKeychainQuery {
        let service = "\(String.passwordVaultKey)_\(seedProvider())"
        return TKKeychainQuery(
            item: .genericPassword(service: service, account: .passwordBiometryMigratedKey),
            accessGroup: nil,
            biometry: .none,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }

    func getPasswordQuery() -> TKKeychainQuery {
        let service = "\(String.passwordVaultKey)_\(seedProvider())"
        return TKKeychainQuery(
            item: .genericPassword(service: service, account: .passwordKey),
            accessGroup: nil,
            biometry: .current,
            accessible: .whenUnlockedThisDeviceOnly
        )
    }

    func decryptMnemonics(_ encryptedMnemonics: EncryptedMnemonics, password: String) async throws -> Mnemonics {
        let data = try await ScryptHashBox.decrypt(
            string: encryptedMnemonics.ct,
            salt: encryptedMnemonics.salt,
            N: encryptedMnemonics.N,
            r: encryptedMnemonics.r,
            p: encryptedMnemonics.p,
            password: password,
            dkLen: MnemonicsEncryptionParams.passwordKeyLength
        )

        let decrypted = try JSONDecoder().decode([String: MnemonicItem].self, from: data)
        var result = Mnemonics()
        var dropped = 0
        for (identifier, item) in decrypted {
            do {
                result[identifier] = try Mnemonic(
                    mnemonicWords: item.mnemonic.components(separatedBy: " ")
                )
            } catch {
                dropped += 1
                logger.e(
                    "🪵 native mnemonics decode dropped invalid item id=\(identifier.redactedMnemonicIdentifier): \(error)"
                )
            }
        }
        if dropped > 0 {
            logger.e("🪵 native mnemonics decode summary: total=\(decrypted.count), dropped=\(dropped)")
        }
        return result
    }

    func encryptMnemonics(_ mnemonics: Mnemonics, password: String) async throws -> EncryptedMnemonics {
        var toEncrypt = [String: MnemonicItem]()
        for item in mnemonics {
            toEncrypt[item.key] = MnemonicItem(
                identifier: item.key,
                mnemonic: item.value.mnemonicWords.joined(separator: " ")
            )
        }
        let data = try JSONEncoder().encode(toEncrypt)

        let salt = try SecureRandom.getRandomBytes(length: 32)
        let ct = try await ScryptHashBox.encrypt(
            data: data,
            salt: salt,
            N: MnemonicsEncryptionParams.N,
            r: MnemonicsEncryptionParams.r,
            p: MnemonicsEncryptionParams.p,
            password: password,
            dkLen: MnemonicsEncryptionParams.passwordKeyLength
        )

        return EncryptedMnemonics(
            kind: "encrypted-scrypt-tweetnacl",
            N: MnemonicsEncryptionParams.N,
            r: MnemonicsEncryptionParams.r,
            p: MnemonicsEncryptionParams.p,
            salt: salt.toHexString(),
            ct: ct
        )
    }

    func saveEncryptedMnemonics(_ encryptedMnemonics: EncryptedMnemonics) throws {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(encryptedMnemonics)
        let bytes = [UInt8](data)
        let chunks = stride(from: 0, to: bytes.count, by: .chunksSize).map {
            Array(bytes[$0 ..< Swift.min($0 + .chunksSize, bytes.count)])
        }
        do {
            try chunks.enumerated().forEach { index, chunk in
                let query = getChunkQuery(index: index)
                try keychainVault.set(Data(chunk), query: query)
            }
            let countQuery = getChunksCountQuery()
            try keychainVault.set(chunks.count, query: countQuery)
        } catch {
            throw Error.other(error)
        }
    }

    func loadEncryptedMnemonics() throws -> EncryptedMnemonics {
        let count: Int
        do {
            let countQuery = getChunksCountQuery()
            count = try keychainVault.get(query: countQuery)
        } catch TKKeychainError.noItem {
            throw Error.noMnemonic
        }

        do {
            let encryptedMnemonicsData = try (0 ..< count)
                .map {
                    let query = getChunkQuery(index: $0)
                    return try keychainVault.get(query: query)
                }
                .reduce(into: Data()) { $0 = $0 + $1 }
            return try JSONDecoder().decode(EncryptedMnemonics.self, from: encryptedMnemonicsData)
        } catch {
            throw Error.mnemonicsCorrupted
        }
    }
}

private extension String {
    static let mnemonicsVaultKey = "mnemonics_vault"
    static let passwordVaultKey = "password_vault"
    static let encryptedMnemonicsChunksCountKey = "encrypted_chunks_count"
    static let encryptedMnemonicsChunkKey = "encrypted_chunk"
    static let passwordKey = "biometry_passcode"
    static let passwordBiometryMigratedKey = "biometry_passcode_current_set_migrated"

    var redactedMnemonicIdentifier: String {
        let prefixLength = Swift.min(8, count)
        return String(prefix(prefixLength))
    }
}

private extension Int {
    static let chunksSize = 2048
}
