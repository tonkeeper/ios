import Foundation
import TKLogging
import TonSwift

public extension Wallet {
    /// The swap wallet of a legacy wallet: its TON (v4R2 or v5R1) and TRON addresses, known to no
    /// backend and signed with the keys they were created with. Nil where the swap cannot sign.
    var legacySwapWallet: MultichainSwapWallet? {
        guard multichainWalletState == nil,
              kind == .regular,
              network == .mainnet,
              let tron
        else {
            return nil
        }
        do {
            let tonAddressType: MultichainWalletAddressType
            switch try contractVersion {
            case .v4R2:
                tonAddressType = .tonV4R2
            case .v5R1:
                tonAddressType = .tonV5R1
            case .v3R1, .v3R2, .v4R1, .v5Beta:
                return nil
            }
            return try MultichainSwapWallet(
                wallet: self,
                addresses: [
                    MultichainWalletAddress(
                        chain: .ton,
                        address: friendlyAddress.toString(),
                        type: tonAddressType,
                        publicKey: MultichainPublicKey(
                            defaultHex: "0x" + publicKey.data.hexString(),
                            segWit: ""
                        )
                    ),
                    MultichainWalletAddress(
                        chain: .tron,
                        address: tron.address.base58
                    ),
                ],
                registration: .unregistered,
                keys: .legacy
            )
        } catch {
            Log.w("legacy swap wallet is unavailable: the TON address cannot be derived", error: error)
            return nil
        }
    }
}
