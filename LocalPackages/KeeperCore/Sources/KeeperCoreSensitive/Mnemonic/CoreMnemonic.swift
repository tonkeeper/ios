import Foundation
import KeeperCoreComponents
import TKLogging
import TonSwift

public typealias CoreMnemonicIdentifier = String

public struct CoreMnemonic: Equatable, Codable, Sendable {
    public let mnemonicWords: [String]
    public let type: DerivationType

    public init(mnemonicWords: [String], type: DerivationType) {
        self.mnemonicWords = mnemonicWords
        self.type = type
    }
}

public extension CoreMnemonic {
    enum Error: Swift.Error {
        case incorrectWordsForDerivationType
        case unknownMnemonicType
    }

    func toKeyPair() throws(Error) -> KeyPair {
        switch type {
        case .ton:
            do {
                return try TonSwift.Mnemonic.mnemonicToPrivateKey(
                    mnemonicArray: mnemonicWords
                )
            } catch {
                #if DEBUG
                    Log.e("🪵 invalid ton mnemonic words: \(error)")
                #endif
                throw .incorrectWordsForDerivationType
            }
        case .bip39, .bip39soft:
            do {
                return try BIP39Mnemonic.bip39MnemonicToKeyPair(
                    mnemonicArray: mnemonicWords
                )
            } catch {
                #if DEBUG
                    Log.e("🪵 invalid bip39 mnemonic words: \(error)")
                #endif
                throw .incorrectWordsForDerivationType
            }
        case .unknown:
            throw .unknownMnemonicType
        }
    }
}
