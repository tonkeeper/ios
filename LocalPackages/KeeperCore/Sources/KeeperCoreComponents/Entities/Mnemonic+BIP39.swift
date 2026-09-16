import CryptoKit
import Foundation
import TonSwift
import TweetNacl

public enum BIP39Mnemonic {
    public static func isValidBip39Mnemonic(mnemonicArray: [String]) -> Bool {
        let mnemonic = normalizeMnemonic(src: mnemonicArray)
        let words = TonSwift.Mnemonic.words

        guard !mnemonic.isEmpty,
              mnemonic.allSatisfy({ words.contains($0) }),
              mnemonic.count % 3 == 0,
              (12 ... 24).contains(mnemonic.count)
        else {
            return false
        }

        var bits = ""
        for word in mnemonic {
            guard let idx = words.firstIndex(of: word) else { return false }
            let bin = String(idx, radix: 2)
            bits += String(repeating: "0", count: 11 - bin.count) + bin
        }

        let entLength = mnemonic.count * 11 * 32 / 33
        let checksumLen = entLength / 32

        let entBits = bits.prefix(entLength)
        let csBits = bits.suffix(checksumLen)

        var entropyBytes: [UInt8] = []
        var i = entBits.startIndex
        while i < entBits.endIndex {
            let next = entBits.index(i, offsetBy: 8)
            let byteStr = String(entBits[i ..< next])
            guard let byte = UInt8(byteStr, radix: 2) else { return false }
            entropyBytes.append(byte)
            i = next
        }

        let hashData = Data(entropyBytes).sha256()

        let hashBits =
            hashData
                .map { byte -> String in
                    let bin = String(byte, radix: 2)
                    return String(repeating: "0", count: 8 - bin.count) + bin
                }
                .joined()
                .prefix(checksumLen)

        return csBits == hashBits
    }

    public static func isValidBip39SoftMnemonic(mnemonicArray: [String]) -> Bool {
        guard !mnemonicArray.isEmpty else { return false }
        let mnemonic = TonSwift.Mnemonic.normalizeMnemonic(src: mnemonicArray)
        guard mnemonic.allSatisfy({ TonSwift.Mnemonic.words.contains($0) }) else { return false }
        return mnemonic.count % 3 == 0
    }

    public static func bip39MnemonicToSeed(mnemonicArray: [String], password: String = "") -> Data {
        let salt: (_ password: String) -> String = { password in
            "mnemonic" + password
        }

        let mnemonicBuffer = Data(normalizeMnemonic(src: mnemonicArray).joined(separator: " ").utf8)
        let saltBuffer = Data(salt(password).utf8)

        let res = pbkdf2Sha512(phrase: mnemonicBuffer, salt: saltBuffer, iterations: 2048, keyLength: 64)

        return Data(res)
    }

    public static func bip39MnemonicToKeyPair(mnemonicArray: [String]) throws -> TonSwift.KeyPair {
        let seed = bip39MnemonicToSeed(mnemonicArray: mnemonicArray)

        let derived = try Ed25519.derivePath(path: "m/44'/607'/0'", seed: seed.hexString())

        let keyPair = try TweetNacl.NaclSign.KeyPair.keyPair(fromSeed: derived.key)
        return KeyPair(publicKey: .init(data: keyPair.publicKey), privateKey: .init(data: keyPair.secretKey))
    }

    private static func normalizeMnemonic(src: [String]) -> [String] {
        return src.map { $0.lowercased() }
    }
}

private enum Ed25519 {
    enum Error: Swift.Error {
        case sharedSecretError(Swift.Error)
        case derivePathError(String)
    }

    static let ED25519_CURVE = "ed25519 seed"
    static let HARDENED_OFFSET: UInt32 = 0x8000_0000

    struct Keys {
        var key: Data
        var chainCode: Data
    }

    static func getMasterKeyFromSeed(seed: String) throws -> Keys {
        guard let seedData = Data(strictHex: seed) else {
            throw Error.derivePathError("Invalid seed hex string")
        }

        let hmac = HMAC<SHA512>.authenticationCode(for: seedData, using: SymmetricKey(data: ED25519_CURVE.data(using: .utf8)!))
        let I = Data(hmac)
        let IL = I.prefix(32)
        let IR = I.suffix(from: 32)

        return Keys(key: IL, chainCode: IR)
    }

    static func CKDPriv(keys: Keys, index: UInt32) -> Keys {
        var indexData = Data(count: 4)
        indexData.withUnsafeMutableBytes { $0.bindMemory(to: UInt8.self).baseAddress?.withMemoryRebound(to: UInt32.self, capacity: 1) {
            $0.pointee = index.bigEndian
        }}

        let data = Data([0]) + keys.key + indexData
        let hmacValue = HMAC<SHA512>.authenticationCode(for: data, using: SymmetricKey(data: keys.chainCode))
        let I = Data(hmacValue)
        let IL = I.prefix(32)
        let IR = I.suffix(from: 32)

        return Keys(key: IL, chainCode: IR)
    }

    static func isValidPath(path: String) -> Bool {
        let pathRegex = #"^m(\/[0-9]+')+$"#
        let regex = try? NSRegularExpression(pattern: pathRegex)

        let range = NSRange(location: 0, length: path.utf16.count)
        guard regex?.firstMatch(in: path, options: [], range: range) != nil else {
            return false
        }

        return !path.split(separator: "/").dropFirst().map { $0.replacingOccurrences(of: "'", with: "") }.contains { Int($0) == nil }
    }

    static func derivePath(path: String, seed: String, offset: UInt32 = HARDENED_OFFSET) throws -> Keys {
        guard isValidPath(path: path) else {
            throw Error.derivePathError("Invalid derivation path")
        }

        var keys = try getMasterKeyFromSeed(seed: seed)

        let segments = path
            .split(separator: "/")
            .dropFirst()
            .map { $0.replacingOccurrences(of: "'", with: "") }
            .compactMap { UInt32($0) }

        for segment in segments {
            keys = CKDPriv(keys: keys, index: segment + offset)
        }

        return keys
    }
}
