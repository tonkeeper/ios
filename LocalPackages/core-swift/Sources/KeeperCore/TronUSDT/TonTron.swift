import Foundation
import TronSwift
import TonSwift
import TKCryptoKit

public enum TonTron {
  public static func tonMnemonicToTronMnemonic(_ tonMnemonic: [String]) -> [String] {
    let entropy = TonSwift.Mnemonic.mnemonicToEntropy(mnemonicArray: tonMnemonic)
    let patchedEntropy = patchTonEntropy(entropy: entropy)
    let tronMnemonic = TronSwift.Mnemonic.entropyToMnemonic(entropy: patchedEntropy)
    return tronMnemonic
  }
  
  public static func keyPair(tonMnemonic: [String]) -> TronSwift.KeyPair {
    let tronMnemonic = tonMnemonicToTronMnemonic(tonMnemonic)
    let keyPair = HDKeys.keyPair(mnemonic: tronMnemonic, derivationCurve: Secp256k1DerivationCurve())
    return keyPair
  }
  
  public static func derivedKeyPair(tonMnemonic: [String], index: Int) throws -> TronSwift.KeyPair {
    let tronMnemonic = tonMnemonicToTronMnemonic(tonMnemonic)
    let keyPair = try HDKeys.derivedKeyPair(mnemonic: tronMnemonic,
                                            purpose: 44,
                                            coin: 195,
                                            account: 0,
                                            chain: 0,
                                            index: index,
                                            derivationCurve: Secp256k1DerivationCurve())
    return keyPair
  }
  
  private static func patchTonEntropy(entropy: Data) -> Data {
    let rangeUpper = (Constants.mnemonicsWordNumber * 11 - Constants.checksumBits) / 8
    return HMAC.sha256(message: entropy, key: Constants.networkLabel.data(using: .utf8)!)[0 ..< rangeUpper]
  }
  
  private struct Constants {
    static let networkLabel = "trx-0x2b6653dc_root"
    static let mnemonicsWordNumber = 12
    static let checksumBits = 4
  }
}
