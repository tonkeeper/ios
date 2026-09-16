import TKLogging
import TonSwift

public enum DerivationType: Codable {
    case ton
    case bip39
    case bip39soft
    case unknown
}

public extension DerivationType {
    var isKnown: Bool {
        !isUnknown
    }

    var isUnknown: Bool {
        switch self {
        case .unknown:
            true
        default:
            false
        }
    }
}

public extension DerivationType {
    static func guessByWords(
        _ words: [String]
    ) -> Self {
        if TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words) {
            return .ton
        }
        if BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words) {
            return .bip39
        }
        if BIP39Mnemonic.isValidBip39SoftMnemonic(mnemonicArray: words) {
            return .bip39soft
        }
        return .unknown
    }

    static func resolveByWords(
        _ words: [String],
        publicKey: TonSwift.PublicKey
    ) -> Self {
        guard isAmbiguous(words) else {
            return guessByWords(words)
        }
        do {
            if try BIP39Mnemonic.bip39MnemonicToKeyPair(mnemonicArray: words).publicKey.data == publicKey.data {
                return .bip39
            }
        } catch {
            Log.w("failed to derive bip39 key pair for ambiguous mnemonic resolution: \(error)")
        }
        do {
            if try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: words).publicKey.data == publicKey.data {
                return .ton
            }
        } catch {
            Log.w("failed to derive ton key pair for ambiguous mnemonic resolution: \(error)")
        }
        Log.w("ambiguous mnemonic does not match ton or bip39 derivation for the given public key, falling back to guess")
        return guessByWords(words)
    }

    static func isAmbiguous(_ words: [String]) -> Bool {
        TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words)
            && BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words)
    }

    static func shouldOfferWalletKindSelection(_ words: [String]) -> Bool {
        isAmbiguous(words)
    }
}
