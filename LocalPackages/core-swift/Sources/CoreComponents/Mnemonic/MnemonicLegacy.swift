import Foundation
import TonSwift
import TweetNacl

/** Backport of TonSwift implementation with bug. We should keep bug to allow user
 * to import incorrent seed phrase wallet */
public enum MnemonicLegacy {
    public static func isValidBip39Mnemonic(mnemonicArray: [String]) -> Bool {
        guard !mnemonicArray.isEmpty else { return false }
        let mnemonic = TonSwift.Mnemonic.normalizeMnemonic(src: mnemonicArray)
        guard mnemonic.allSatisfy({ TonSwift.Mnemonic.words.contains($0) }) else { return false }
        return mnemonic.count % 3 == 0
    }

    public static func anyMnemonicToPrivateKey(mnemonicArray: [String], password: String = "") throws -> KeyPair {
        if TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: mnemonicArray) {
            return try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonicArray)
        } else {
            return try self.bip39MnemonicToPrivateKey(mnemonicArray: mnemonicArray)
        }
    }

    private static func bip39MnemonicToPrivateKey(mnemonicArray: [String]) throws -> KeyPair {
        guard self.isValidBip39Mnemonic(mnemonicArray: mnemonicArray) else {
            throw NSError(domain: "Mnemonic", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid mnemonic"])
        }

        let seed = TonSwift.Mnemonic.bip39MnemonicToSeed(mnemonicArray: mnemonicArray)

        do {
            let derived = try Ed25519.derivePath(path: "m/44'/607'/0'", seed: seed.hexString())

            let keyPair = try TweetNacl.NaclSign.KeyPair.keyPair(fromSeed: derived.key)
            return KeyPair(publicKey: .init(data: keyPair.publicKey), privateKey: .init(data: keyPair.secretKey))

        } catch {
            throw error
        }
    }
}
