import Foundation
import TKCryptoKit

public enum HDKeys {
    public static func derivedKeyPair(
        mnemonic: [String],
        path: String,
        derivationCurve: DerivationCurve
    ) throws -> KeyPair {
        let seed = Mnemonic.mnemonicToSeed(mnemonic: mnemonic)
        let privateKey = try derivedPrivateKey(seed: seed, path: path, derivationCurve: derivationCurve)
        let publicKey = privateKey.publicKey(compressed: false, curve: derivationCurve)

        return KeyPair(publicKey: publicKey, privateKey: privateKey)
    }

    public static func derivedKeyPair(
        mnemonic: [String],
        purpose: Int,
        coin: Int,
        account: Int,
        chain: Int,
        index: Int,
        derivationCurve: DerivationCurve
    ) throws -> KeyPair {
        let path = "m/\(purpose)'/\(coin)'/\(account)'/\(chain)/\(index)"
        return try derivedKeyPair(mnemonic: mnemonic, path: path, derivationCurve: derivationCurve)
    }

    private static func privateKey(
        seed: Data,
        derivationCurve: DerivationCurve
    ) -> PrivateKey {
        let hmac = HMAC.sha512(message: seed, key: derivationCurve.seedSaltData)
        let privateKey = hmac[0 ..< 32]
        let chainCode = hmac[32 ..< 64]
        return PrivateKey(
            data: privateKey,
            chainCode: chainCode
        )
    }

    private static func derivedPrivateKey(
        seed: Data,
        path: String,
        derivationCurve: DerivationCurve
    ) throws -> PrivateKey {
        let privateKey = privateKey(seed: seed, derivationCurve: derivationCurve)
        var path = path
        path = path.replacingOccurrences(of: "m/", with: "")
        let segments = path.split(separator: "/")

        var key: PrivateKey = privateKey
        for segment in segments {
            let hardened = segment.contains("'")
            guard let index = UInt32(segment.replacingOccurrences(of: "'", with: "")) else {
                throw DerivationError.invalidPath(path)
            }
            key = try key.deriveKey(index: index, hardened: hardened, curve: derivationCurve)
        }

        return key
    }
}
