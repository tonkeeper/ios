import Foundation
import TonSwift
import WalletCore

/// What one Ledger account's device apps return at pairing to make it a multichain wallet.
public struct LedgerMultichainAccount: Sendable {
    /// The TON app's signature of the wallet key proof, made with the inputs `LedgerWalletKey` names.
    public let proofSignature: Data
    public let keys: LedgerAppKeys

    public init(proofSignature: Data, keys: LedgerAppKeys) {
        self.proofSignature = proofSignature
        self.keys = keys
    }
}

/// The keys one Ledger account's chain apps hand out, each with the address the app derived from it.
public struct LedgerAppKeys: Sendable {
    public struct Key: Sendable {
        public let publicKey: Data
        public let address: String

        public init(publicKey: Data, address: String) {
            self.publicKey = publicKey
            self.address = address
        }
    }

    /// The Ethereum app's uncompressed secp256k1 key: one address on every EVM chain.
    public let evm: Key?
    /// The Tron app's uncompressed secp256k1 key.
    public let tron: Key?
    /// The Solana app's ed25519 key, which is the address itself.
    public let solana: Data?
    /// The Bitcoin app's extended key of `m/84'/0'/account'`, `xpub…`: the wallet's one address is its `0/0`.
    public let bitcoin: String?

    public init(evm: Key? = nil, tron: Key? = nil, solana: Data? = nil, bitcoin: String? = nil) {
        self.evm = evm
        self.tron = tron
        self.solana = solana
        self.bitcoin = bitcoin
    }
}

extension LedgerMultichainAccount {
    /// The account's wallet seed, app key and state: TON v4R2 and one address on each chain of `chains` its keys reach,
    /// in that order.
    func wallet(tonPublicKey: Data, chains: [MultichainChain]) throws -> (seed: Data, appPrivateKey: Data, state: MultichainWalletState) {
        let wallet = try LedgerWalletKey.wallet(tonPublicKey: tonPublicKey, proofSignature: proofSignature)
        let tonAddress = try WalletV4R2(publicKey: tonPublicKey).address().toFriendly(bounceable: false).toString()
        let ton = chains.contains(.ton)
            ? [MultichainWalletAddress(chain: .ton, address: tonAddress, type: .tonV4R2, publicKey: .ledger(tonPublicKey))]
            : []
        let state = try MultichainWalletState(walletId: wallet.walletId, addresses: ton + keys.addresses(chains: chains))
        return (wallet.seed, wallet.appPrivateKey, state)
    }
}

extension LedgerAppKeys {
    enum Failure: Error {
        case invalidKey(MultichainChain)
        case addressMismatch(MultichainChain, device: String, derived: String)
    }

    /// One address on each chain of `chains` these keys reach, in that order. An address the device reported
    /// is used only when its key derives it.
    public func addresses(chains: [MultichainChain]) throws -> [MultichainWalletAddress] {
        let evm = try evm.map { try Self.address(of: $0, chain: .eth, coin: .ethereum) }
        let tron = try tron.map { try Self.address(of: $0, chain: .tron, coin: .tron) }
        let solana = try solana.map { try Self.solanaAddress(of: $0) }
        let bitcoin = try bitcoin.map { try Self.bitcoinAddress(of: $0) }
        return chains.compactMap { chain in
            switch chain {
            case .tron:
                tron
            case .sol:
                solana
            case .btc:
                bitcoin
            case _ where chain.isEVM:
                evm.map { MultichainWalletAddress(chain: chain, address: $0.address, publicKey: $0.publicKey) }
            default:
                nil
            }
        }
    }

    private static func address(of key: Key, chain: MultichainChain, coin: CoinType) throws -> MultichainWalletAddress {
        guard let publicKey = WalletCore.PublicKey(data: key.publicKey, type: .secp256k1Extended) else {
            throw Failure.invalidKey(chain)
        }
        let derived = coin.deriveAddressFromPublicKey(publicKey: publicKey)
        // The Ethereum app reports its address in lowercase, without `0x`.
        let isReported = coin == .ethereum ? derived.dropFirst(2).lowercased() == key.address.lowercased() : derived == key.address
        guard isReported else {
            throw Failure.addressMismatch(chain, device: key.address, derived: derived)
        }
        return MultichainWalletAddress(chain: chain, address: derived, publicKey: .ledger(key.publicKey))
    }

    /// ChainKit keeps the account key as `zpub` and the address key, `0/0`, beside it.
    private static func bitcoinAddress(of accountXpub: String) throws -> MultichainWalletAddress {
        guard let zpub = BitcoinExtendedKey.converted(accountXpub, to: BitcoinExtendedKey.zpubVersion),
              let key = HDWallet.getPublicKeyFromExtended(extended: zpub, coin: .bitcoin, derivationPath: "m/84'/0'/0'/0/0")
        else {
            throw Failure.invalidKey(.btc)
        }
        return MultichainWalletAddress(
            chain: .btc,
            address: CoinType.bitcoin.deriveAddressFromPublicKey(publicKey: key),
            type: .btcP2WPKH,
            publicKey: MultichainPublicKey(defaultHex: "0x" + key.data.hexString(), segWit: zpub)
        )
    }

    private static func solanaAddress(of key: Data) throws -> MultichainWalletAddress {
        guard let publicKey = WalletCore.PublicKey(data: key, type: .ed25519) else {
            throw Failure.invalidKey(.sol)
        }
        return MultichainWalletAddress(chain: .sol, address: CoinType.solana.deriveAddressFromPublicKey(publicKey: publicKey), publicKey: .ledger(key))
    }
}

/// A BIP-32 extended key re-encoded under another version, as the Bitcoin app reports `xpub` and ChainKit keeps `zpub`.
enum BitcoinExtendedKey {
    static let xpubVersion: UInt32 = 0x0488_B21E
    static let zpubVersion: UInt32 = 0x04B2_4746

    static func converted(_ key: String, to version: UInt32) -> String? {
        guard let data = WalletCore.Base58.decode(string: key), data.count == 78 else {
            return nil
        }
        return WalletCore.Base58.encode(data: withUnsafeBytes(of: version.bigEndian) { Data($0) } + data.dropFirst(4))
    }
}

private extension MultichainPublicKey {
    /// A Ledger app hands out keys, not extended keys, so there is no SegWit form.
    static func ledger(_ key: Data) -> MultichainPublicKey {
        MultichainPublicKey(defaultHex: "0x" + key.hexString(), segWit: "")
    }
}
