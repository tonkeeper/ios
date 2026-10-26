import ChainKit
import Foundation
import KeeperCoreSensitive
import TonSwift
import TronSwift

enum SwapSigningWallet {
    case hd(CryptoWallet)
    case legacy(ton: ChainKit.PrivateKey, tron: ChainKit.PrivateKey)

    /// The keys a legacy wallet's addresses were created with: the TON key of the phrase under its
    /// own derivation type and the TRON key `WalletTron` derives through `TonTron`, whatever the
    /// type of the phrase. A BIP39 phrase imported as a legacy wallet keeps that TRON address, not
    /// the one of the BIP39 branch an HD wallet would sign for.
    init(
        legacyMnemonic mnemonic: CoreMnemonic,
        tronAddress: TronSwift.Address
    ) throws(MultichainSwapExecutionFailure) {
        let tonKeyPair: TonSwift.KeyPair
        let tronKeyPair: TronSwift.KeyPair
        do {
            tonKeyPair = try mnemonic.toKeyPair()
            tronKeyPair = try TonTron.derivedKeyPair(tonMnemonic: mnemonic.mnemonicWords, index: 0)
        } catch {
            throw .internal(reason: "failed to derive legacy swap keys due to error: \(error.logDescription)")
        }
        let ton = try Self.chainKitPrivateKey(Data(tonKeyPair.privateKey.data.prefix(Self.ed25519SeedLength)))
        guard ton.core.getPublicKey(coinType: .ton).data.asData == tonKeyPair.publicKey.data else {
            throw .internal(reason: "TON swap key does not match the wallet public key")
        }
        guard (try? TronSwift.Address(publicKey: tronKeyPair.publicKey)) == tronAddress else {
            throw .internal(reason: "TRON swap key does not match the wallet TRON address")
        }
        self = try .legacy(ton: ton, tron: Self.chainKitPrivateKey(tronKeyPair.privateKey.data))
    }

    func privateKey(chain: MultichainChain) throws(MultichainSwapExecutionFailure) -> ChainKit.PrivateKey {
        switch self {
        case let .hd(wallet):
            return wallet.getPrivateKey(chain: chain.asChainKitChain)
        case let .legacy(ton, tron):
            switch chain {
            case .ton:
                return ton
            case .tron:
                return tron
            case .eth, .base, .btc, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
                throw .internal(reason: "a legacy wallet has no \(chain.rawValue) key")
            }
        }
    }

    func publicKey(chain: MultichainChain) throws(MultichainSwapExecutionFailure) -> PubKey {
        switch self {
        case let .hd(wallet):
            return wallet.getPublicKey(chain: chain.asChainKitChain)
        case .legacy:
            let coinType: Wallet_core_kotlinCoinType = chain == .ton ? .ton : .tron
            let publicKey = try privateKey(chain: chain).core.getPublicKey(coinType: coinType)
            return PubKey(defaultHex: "0x" + publicKey.data.asData.hexString(), segWit: "")
        }
    }
}

private extension SwapSigningWallet {
    static let ed25519SeedLength = 32

    static func chainKitPrivateKey(_ data: Data) throws(MultichainSwapExecutionFailure) -> ChainKit.PrivateKey {
        do {
            return try ChainKit.PrivateKey(core: Wallet_core_kotlinPrivateKey(data: data.asKotlinByteArray))
        } catch {
            throw .internal(reason: "failed to build a swap signing key due to error: \(error.logDescription)")
        }
    }
}
