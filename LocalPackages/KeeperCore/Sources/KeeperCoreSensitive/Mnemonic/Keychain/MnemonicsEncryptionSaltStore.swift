import Foundation
import Security
import TKLogging

struct MnemonicsEncryptionSaltStore {
    private let seedProvider: () -> String
    private let keychain: any SecureStorageKeychain
    private let logger = LogDomain.mnemonicStorage

    init(
        seedProvider: @escaping () -> String,
        keychain: any SecureStorageKeychain
    ) {
        self.seedProvider = seedProvider
        self.keychain = keychain
    }

    func getSalt() throws(MnemonicsRepositoryV2Failure) -> Data {
        do {
            return try readSalt()
        } catch MnemonicsRepositoryV2Failure.notFound {
            let salt: Data
            do {
                salt = try MnemonicsRepositoryV2Crypto.makeSalt()
            } catch {
                throw mnemonicsFailure(from: error)
            }
            do {
                try saveSalt(salt)
                return salt
            } catch MnemonicsRepositoryV2Failure.duplicate {
                return try readSalt()
            }
        }
    }

    func deleteSalt() throws(MnemonicsRepositoryV2Failure) {
        for serviceKey in knownSaltServiceKeys {
            try deleteSalt(serviceKey: serviceKey)
        }
    }
}

private extension MnemonicsEncryptionSaltStore {
    enum QueryType {
        case get
        case add(Data)
        case delete(serviceKey: String)
    }

    func readSalt() throws(MnemonicsRepositoryV2Failure) -> Data {
        let query = keychainQuery(for: .get) as CFDictionary
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)
        switch status {
        case errSecItemNotFound:
            throw .notFound
        case errSecSuccess:
            break
        default:
            logger.e("Failed to read v2 mnemonics encryption salt. status=\(status)")
            throw .securityFailure(code: status)
        }

        guard let data = item as? Data else {
            logger.e("Keychain returned unexpected value type for v2 mnemonics encryption salt. type=\(type(of: item))")
            throw .decodeFailure(message: "wrong encryption salt value type: \(type(of: item))")
        }
        return try validateSalt(data)
    }

    func saveSalt(_ salt: Data) throws(MnemonicsRepositoryV2Failure) {
        let salt = try validateSalt(salt)
        let status = keychain.add(
            keychainQuery(for: .add(salt)) as CFDictionary,
            result: nil
        )
        switch status {
        case errSecDuplicateItem:
            throw .duplicate
        case errSecSuccess:
            return
        default:
            logger.e("Failed to save v2 mnemonics encryption salt. status=\(status)")
            throw .securityFailure(code: status)
        }
    }

    func validateSalt(_ salt: Data) throws(MnemonicsRepositoryV2Failure) -> Data {
        guard salt.count == MnemonicsRepositoryV2Crypto.saltLength else {
            logger.e("Invalid v2 mnemonics encryption salt length. saltLength=\(salt.count)")
            throw .cryptographyFailure(
                message: "invalid encryption salt length"
            )
        }
        return salt
    }

    func deleteSalt(
        serviceKey: String
    ) throws(MnemonicsRepositoryV2Failure) {
        let status = keychain.delete(
            keychainQuery(for: .delete(serviceKey: serviceKey)) as CFDictionary
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.e("Failed to delete v2 mnemonics encryption salt. service=\(serviceKey), status=\(status)")
            throw .securityFailure(code: status)
        }
    }

    func keychainQuery(for type: QueryType) -> [CFString: Any] {
        switch type {
        case .get:
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true as AnyObject,
            ]
        case let .add(value):
            return [
                kSecClass: securityClass,
                kSecAttrAccessible: keychainWriteAccessType,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
                kSecValueData: value as AnyObject,
            ]
        case let .delete(serviceKey):
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
            ]
        }
    }

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

    var serviceKey: String {
        Self.serviceKey(seed: seedProvider())
    }

    var knownSaltServiceKeys: [String] {
        let seed = seedProvider()
        return [
            Self.legacyServiceKey(slot: .a, seed: seed),
            Self.legacyServiceKey(slot: .b, seed: seed),
            Self.serviceKey(seed: seed),
        ]
    }

    var accountKey: String {
        "argon2_salt"
    }

    var keychainWriteAccessType: Any {
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }

    var securityClass: Any {
        kSecClassGenericPassword
    }

    static func serviceKey(seed: String) -> String {
        "v2mnemonics_salt_\(seed)"
    }

    static func legacyServiceKey(
        slot: ABStorageSlot,
        seed: String
    ) -> String {
        switch slot {
        case .a:
            return "v2mnemonics_params_\(seed)"
        case .b:
            return "v2mnemonics_b_params_\(seed)"
        }
    }
}
