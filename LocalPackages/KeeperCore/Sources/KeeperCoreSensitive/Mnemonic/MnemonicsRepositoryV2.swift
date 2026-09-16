import CryptoKit
import Foundation
import Security
import Sodium
import TonSwift

public enum MnemonicsRepositoryV2Failure: Error {
    case encodeFailure(message: String)
    case decodeFailure(message: String)
    case cryptographyFailure(message: String)
    case securityFailure(code: OSStatus)
    case storageFailure(underlying: Error)
    case duplicate
    case notFound
}

public protocol MnemonicsRepositoryV2 {
    associatedtype MnemonicItem: Codable

    func hasMnemonic() throws(MnemonicsRepositoryV2Failure) -> Bool

    func add(
        _ mnemonic: MnemonicItem,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure)

    func upsert(
        _ mnemonic: MnemonicItem,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure)

    func get(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) -> MnemonicItem

    func getAll() throws(MnemonicsRepositoryV2Failure) -> [CoreMnemonicIdentifier: MnemonicItem]

    func delete(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure)
}

public protocol RawMnemonicsDataRepositoryV2: MnemonicsRepositoryV2 where MnemonicItem == RawMnemonicsData {}

public struct RawMnemonicsData: Codable {
    var data: Data
}

public enum MnemonicsRepositoryV2CryptoFailure: Error {
    case encryptionFailure(message: String)
    case decryptionFailure(message: String)
    case invalidMnemonicData(message: String)
    case cryptographyFailure(message: String)

    var message: String {
        switch self {
        case let .encryptionFailure(message):
            "encryption failure: \(message)"
        case let .decryptionFailure(message):
            "decryption failure: \(message)"
        case let .invalidMnemonicData(message):
            "invalid mnemonic data: \(message)"
        case let .cryptographyFailure(message):
            "cryptography internal failure: \(message)"
        }
    }
}

public enum MnemonicsRepositoryV2Crypto {
    public struct Cipher {
        private let key: SymmetricKey

        fileprivate init(key: SymmetricKey) {
            self.key = key
        }

        public func encrypt(
            _ mnemonic: CoreMnemonic
        ) throws(MnemonicsRepositoryV2CryptoFailure) -> RawMnemonicsData {
            let payload: Data
            do {
                payload = try JSONEncoder().encode(mnemonic)
            } catch {
                throw .invalidMnemonicData(
                    message: "failed to encode mnemonic data to json"
                )
            }
            let sealedBox: AES.GCM.SealedBox
            do {
                sealedBox = try AES.GCM.seal(payload, using: key)
            } catch {
                throw .encryptionFailure(
                    message: "failed to seal mnemonic payload due to error: \(error)"
                )
            }
            guard let combined = sealedBox.combined else {
                throw .encryptionFailure(
                    message: "missing sealed box combined data"
                )
            }
            var data = Data()
            data.append(contentsOf: [Self.version])
            data.append(combined)
            return RawMnemonicsData(data: data)
        }

        public func decrypt(
            _ raw: RawMnemonicsData
        ) throws(MnemonicsRepositoryV2CryptoFailure) -> CoreMnemonic {
            guard let first = raw.data.first, first == Self.version else {
                throw .invalidMnemonicData(
                    message: "failed to decode mnemonic from raw data due to empty size"
                )
            }
            let combinedStartIndex = 1
            guard raw.data.count > combinedStartIndex else {
                throw .invalidMnemonicData(
                    message: "failed to decode mnemonic from raw data due to invalid size: \(raw.data.count)"
                )
            }
            let combined = raw.data.subdata(in: combinedStartIndex ..< raw.data.count)
            let sealed: AES.GCM.SealedBox
            do {
                sealed = try AES.GCM.SealedBox(combined: combined)
            } catch {
                throw .decryptionFailure(
                    message: "failed to create sealed box due to error: \(error)"
                )
            }
            let decrypted: Data
            do {
                decrypted = try AES.GCM.open(sealed, using: key)
            } catch {
                throw .decryptionFailure(
                    message: "failed to decrypt mnemonic data due to error: \(error)"
                )
            }
            let decoded: CoreMnemonic
            do {
                decoded = try JSONDecoder().decode(CoreMnemonic.self, from: decrypted)
            } catch {
                throw .invalidMnemonicData(
                    message: "failed to decode mnemonic data from decrypted data to json"
                )
            }
            return decoded
        }

        private static let version: UInt8 = 2
    }

    private static let keyLength = 32

    public static var saltLength: Int {
        argonSaltLength
    }

    public static func makeSalt() throws(MnemonicsRepositoryV2CryptoFailure) -> Data {
        try randomBytes(count: argonSaltLength)
    }

    /// Argon2id cost for key derivation.
    ///
    /// `.production` reads `OpsLimitInteractive` / `MemLimitModerate` straight
    /// from libsodium at derivation time. The test target (via
    /// `@testable import`) injects `.custom(...)` with libsodium's minimum cost.
    enum Argon2Cost {
        case production
        case custom(opsLimit: Int, memLimit: Int)

        func limits(_ pwHash: PWHash) -> (opsLimit: Int, memLimit: Int) {
            switch self {
            case .production:
                (pwHash.OpsLimitInteractive, pwHash.MemLimitModerate)
            case let .custom(opsLimit, memLimit):
                (opsLimit, memLimit)
            }
        }
    }

    public static func unlock(
        passcode: String,
        salt: Data
    ) throws(MnemonicsRepositoryV2CryptoFailure) -> Cipher {
        try unlock(passcode: passcode, salt: salt, cost: .production)
    }

    static func unlock(
        passcode: String,
        salt: Data,
        cost: Argon2Cost
    ) throws(MnemonicsRepositoryV2CryptoFailure) -> Cipher {
        guard salt.count == argonSaltLength else {
            throw .cryptographyFailure(
                message: "invalid salt data: \(salt.count)"
            )
        }
        let key: SymmetricKey
        do {
            key = try deriveArgon2IDKey(passcode: passcode, salt: salt, cost: cost)
        } catch {
            throw .cryptographyFailure(
                message: "argon derivation failed on unlock"
            )
        }
        return Cipher(key: key)
    }

    private static func deriveArgon2IDKey(
        passcode: String,
        salt: Data,
        cost: Argon2Cost
    ) throws(MnemonicsRepositoryV2CryptoFailure) -> SymmetricKey {
        let sodium = Sodium()
        let pwhash = sodium.pwHash
        let limits = cost.limits(pwhash)
        let derived = pwhash.hash(
            outputLength: keyLength,
            passwd: [UInt8](passcode.utf8),
            salt: [UInt8](salt),
            opsLimit: limits.opsLimit,
            memLimit: limits.memLimit,
            alg: .Argon2ID13
        )
        guard let derived else {
            throw .cryptographyFailure(
                message: "missing argon2 derived data"
            )
        }
        return SymmetricKey(data: Data(derived))
    }

    private static var argonSaltLength: Int {
        Sodium().pwHash.SaltBytes
    }

    private static func randomBytes(count: Int) throws(MnemonicsRepositoryV2CryptoFailure) -> Data {
        var data = Data(repeating: 0, count: count)
        let result = try data
            .withUnsafeMutableBytes { bytes -> Result<Int32, MnemonicsRepositoryV2CryptoFailure> in
                guard let baseAddress = bytes.baseAddress else {
                    return .failure(
                        .cryptographyFailure(
                            message: "misssing base address on generating random bytes"
                        )
                    )
                }
                return .success(
                    SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
                )
            }
            .get()
        guard result == errSecSuccess else {
            throw .cryptographyFailure(
                message: "failed to generate random data"
            )
        }
        return data
    }
}

public struct DefaultMnemonicsRepositoryV2 {
    private let encoder: (CoreMnemonic) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData
    private let decoder: (RawMnemonicsData) throws(MnemonicsRepositoryV2Failure) -> CoreMnemonic
    private let rawStorage: any RawMnemonicsDataRepositoryV2

    public init(
        encoder: @escaping (CoreMnemonic) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData,
        decoder: @escaping (RawMnemonicsData) throws(MnemonicsRepositoryV2Failure) -> CoreMnemonic,
        rawStorage: any RawMnemonicsDataRepositoryV2
    ) {
        self.encoder = encoder
        self.decoder = decoder
        self.rawStorage = rawStorage
    }
}

extension DefaultMnemonicsRepositoryV2: MnemonicsRepositoryV2 {
    public func hasMnemonic() throws(MnemonicsRepositoryV2Failure) -> Bool {
        try rawStorage.hasMnemonic()
    }

    public func add(
        _ mnemonic: CoreMnemonic,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let encoded = try encoder(mnemonic)
        try rawStorage.add(encoded, id: id)
    }

    public func upsert(
        _ mnemonic: CoreMnemonic,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let encoded = try encoder(mnemonic)
        try rawStorage.upsert(encoded, id: id)
    }

    public func get(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) -> CoreMnemonic {
        let raw = try rawStorage.get(id: id)
        return try decoder(raw)
    }

    public func getAll() throws(MnemonicsRepositoryV2Failure) -> [CoreMnemonicIdentifier: CoreMnemonic] {
        let rawValues = try rawStorage.getAll()
        var decoded: [CoreMnemonicIdentifier: CoreMnemonic] = [:]
        for (id, rawValue) in rawValues {
            decoded[id] = try decoder(rawValue)
        }
        return decoded
    }

    public func delete(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        try rawStorage.delete(id: id)
    }
}
