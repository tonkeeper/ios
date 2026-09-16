import Foundation
import Security
import TKLogging

struct MnemonicsRawDataSlotStorage: ABSlotStorage {
    struct WriteInput {
        let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
        let passcode: String
    }

    let keychain: any SecureStorageKeychain
    let slot: ABStorageSlot
    let serviceKeys: MnemonicsRawDataStorageServiceKeys
    let encryptionSalt: () throws(MnemonicsRepositoryV2Failure) -> Data
    let keychainQuery: (MnemonicsRawDataStorageKeychainQuery) -> [CFString: Any]
    // Supplied by the owning repository: `.production` for real callers.
    let argon2Cost: MnemonicsRepositoryV2Crypto.Argon2Cost
    let logger = LogDomain.mnemonicStorage

    func prepare() throws(MnemonicsRepositoryV2Failure) {
        try deleteStorageArtifacts()
    }

    func write(_ input: WriteInput) throws(MnemonicsRepositoryV2Failure) {
        guard !input.mnemonics.isEmpty else {
            return
        }
        let stagedRepository = try unlocked(passcode: input.passcode)
        for (identifier, mnemonic) in input.mnemonics {
            try stagedRepository.add(mnemonic, id: identifier)
        }
    }

    func unlocked(
        passcode: String
    ) throws(MnemonicsRepositoryV2Failure) -> DefaultMnemonicsRepositoryV2 {
        let salt = try encryptionSalt()
        let cipher: MnemonicsRepositoryV2Crypto.Cipher
        do {
            cipher = try MnemonicsRepositoryV2Crypto.unlock(
                passcode: passcode,
                salt: salt,
                cost: argon2Cost
            )
        } catch {
            throw .cryptographyFailure(message: error.message)
        }
        func encode(
            _ mnemonic: CoreMnemonic
        ) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData {
            do {
                return try cipher.encrypt(mnemonic)
            } catch {
                throw mnemonicsFailure(from: error)
            }
        }
        func decode(
            _ rawValue: RawMnemonicsData
        ) throws(MnemonicsRepositoryV2Failure) -> CoreMnemonic {
            do {
                return try cipher.decrypt(rawValue)
            } catch {
                throw mnemonicsFailure(from: error)
            }
        }
        return DefaultMnemonicsRepositoryV2(
            encoder: encode,
            decoder: decode,
            rawStorage: self
        )
    }

    func deleteStorageArtifacts() throws(MnemonicsRepositoryV2Failure) {
        let queryBuilder = MnemonicsRawDataStorageKeychainCleaner(
            keychain: keychain,
            keychainQuery: keychainQuery,
            logger: logger
        )
        try queryBuilder.deleteStorageArtifacts(serviceKeys: serviceKeys)
    }
}

extension MnemonicsRawDataSlotStorage: RawMnemonicsDataRepositoryV2 {
    func hasMnemonic() throws(MnemonicsRepositoryV2Failure) -> Bool {
        let query = keychainQuery(
            .checkHasMnemonics(slot: slot)
        ) as CFDictionary
        let status = keychain.copyMatching(query, result: nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            logger.e("Failed to check v2 mnemonics presence. status=\(status)")
            throw .securityFailure(code: status)
        }
    }

    func add(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let data: Data
        do {
            data = try JSONEncoder().encode(mnemonic)
        } catch {
            logger.e("Failed to encode mnemonic for add. id=\(id), type=\(RawMnemonicsData.self), error=\(error)")
            throw .encodeFailure(message: "failed to encode mnemonic \(id): \(error)")
        }
        let query = keychainQuery(
            .addMnemonic(
                id: id,
                value: data,
                slot: slot
            )
        ) as CFDictionary
        let status = keychain.add(query, result: nil)
        switch status {
        case errSecDuplicateItem:
            logger.e("Duplicate mnemonic add attempt. id=\(id), status=\(status)")
            throw .duplicate
        case errSecSuccess:
            return
        default:
            logger.e("Failed to add mnemonic to keychain. id=\(id), status=\(status)")
            throw .securityFailure(code: status)
        }
    }

    func upsert(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let data: Data
        do {
            data = try JSONEncoder().encode(mnemonic)
        } catch {
            logger.e("Failed to encode mnemonic for upsert. id=\(id), type=\(RawMnemonicsData.self), error=\(error)")
            throw .encodeFailure(message: "failed to encode mnemonic \(id): \(error)")
        }
        let addQuery = keychainQuery(
            .addMnemonic(
                id: id,
                value: data,
                slot: slot
            )
        ) as CFDictionary
        let status = keychain.add(addQuery, result: nil)
        switch status {
        case errSecDuplicateItem:
            break
        case errSecSuccess:
            return
        default:
            logger.e("Failed to insert mnemonic during upsert. id=\(id), status=\(status)")
            throw .securityFailure(code: status)
        }
        let updateQuery = keychainQuery(
            .updateMnemonic(
                id: id,
                slot: slot
            )
        ) as CFDictionary
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: data as AnyObject,
        ]
        let updateStatus = keychain.update(
            updateQuery,
            attributes: attributesToUpdate as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        default:
            logger.e("Failed to update mnemonic during upsert. id=\(id), status=\(updateStatus)")
            throw .securityFailure(code: updateStatus)
        }
    }

    func get(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData {
        let query = keychainQuery(
            .getMnemonic(
                id: id,
                slot: slot
            )
        ) as CFDictionary
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)
        switch status {
        case errSecItemNotFound:
            logger.e("Requested mnemonic is not found. id=\(id), status=\(status)")
            throw .notFound
        case errSecSuccess:
            break
        default:
            logger.e("Failed to read mnemonic from keychain. id=\(id), status=\(status)")
            throw .securityFailure(code: status)
        }
        guard let item else {
            logger.e("Keychain returned empty result for mnemonic. id=\(id)")
            throw .decodeFailure(message: "keychain returned empty mnemonic result for id \(id)")
        }
        guard
            let attributes = item as? [String: Any],
            let data = attributes[kSecValueData as String] as? Data
        else {
            logger.e("Keychain returned unexpected value type for mnemonic. id=\(id), type=\(type(of: item))")
            throw .decodeFailure(message: "wrong keychain mnemonic value type: \(type(of: item))")
        }
        let mnemonic: RawMnemonicsData
        do {
            mnemonic = try JSONDecoder().decode(RawMnemonicsData.self, from: data)
        } catch {
            logger.e("Failed to decode mnemonic payload. id=\(id), bytes=\(data.count), error=\(error)")
            throw .decodeFailure(message: "failed to decode mnemonic \(id): \(error)")
        }
        return mnemonic
    }

    func getAll() throws(MnemonicsRepositoryV2Failure) -> [CoreMnemonicIdentifier: RawMnemonicsData] {
        let query = keychainQuery(
            .getAllMnemonics(slot: slot)
        ) as CFDictionary
        var result: CFTypeRef?
        let status = keychain.copyMatching(query, result: &result)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            return [:]
        default:
            logger.e("Failed to read all mnemonics from keychain. status=\(status)")
            throw .securityFailure(code: status)
        }
        guard let result else {
            logger.e("Keychain returned empty result for all mnemonics.")
            throw .decodeFailure(message: "keychain returned empty result for all mnemonics")
        }

        guard let rawValues = result as? [[String: Any]] else {
            logger.e("Keychain returned unexpected value type for all mnemonics. type=\(type(of: result))")
            throw .decodeFailure(message: "wrong keychain all mnemonics value type: \(type(of: result))")
        }
        var values: [CoreMnemonicIdentifier: Data] = [:]
        for rawValue in rawValues {
            guard
                let account = rawValue[kSecAttrAccount as String] as? String,
                let data = rawValue[kSecValueData as String] as? Data
            else {
                logger.e(
                    "Keychain returned malformed item for all mnemonics."
                )
                throw .decodeFailure(message: "malformed keychain mnemonic dictionary item")
            }
            values[account] = data
        }

        let decoder = JSONDecoder()
        var mnemonics: [CoreMnemonicIdentifier: RawMnemonicsData] = [:]
        for (account, data) in values {
            do {
                mnemonics[account] = try decoder.decode(RawMnemonicsData.self, from: data)
            } catch {
                logger.e("Failed to decode mnemonic during getAll. id=\(account), bytes=\(data.count), error=\(error)")
                throw .decodeFailure(message: "failed to decode mnemonic \(account): \(error)")
            }
        }
        return mnemonics
    }

    func delete(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let query = keychainQuery(
            .removeMnemonic(
                id: id,
                slot: slot
            )
        ) as CFDictionary
        let status = keychain.delete(query)
        switch status {
        case errSecItemNotFound:
            logger.e("Cannot delete mnemonic because it does not exist. id=\(id), status=\(status)")
            throw .notFound
        case errSecSuccess:
            return
        default:
            logger.e("Failed to delete mnemonic from keychain. id=\(id), status=\(status)")
            throw .securityFailure(code: status)
        }
    }
}

private extension MnemonicsRawDataSlotStorage {
    func mnemonicsFailure(
        from error: MnemonicsRepositoryV2CryptoFailure
    ) -> MnemonicsRepositoryV2Failure {
        switch error {
        case let .encryptionFailure(message):
            return .encodeFailure(message: message)
        case let .decryptionFailure(message):
            return .decodeFailure(message: message)
        case let .invalidMnemonicData(message):
            return .decodeFailure(message: message)
        case let .cryptographyFailure(message):
            return .cryptographyFailure(message: message)
        }
    }
}
