import Foundation

public enum MultichainWalletAddressType: String, Hashable, Codable, Sendable {
    case tonV3R1 = "v3R1"
    case tonV3R2 = "v3R2"
    case tonV4R1 = "v4R1"
    case tonV4R2 = "v4R2"
    case tonV5R1 = "v5R1"
    case btcP2PKH = "p2pkh"
    case btcP2SHP2WPKH = "p2sh-p2wpkh"
    case btcP2WPKH = "p2wpkh"
    case btcP2TR = "p2tr"
}

public struct MultichainRecipient: Hashable, Codable, Sendable {
    public let chain: MultichainChain
    public let address: String
    public let domain: String?

    public init(chain: MultichainChain, address: String, domain: String? = nil) {
        self.chain = chain
        self.address = address
        self.domain = domain
    }
}

/// An address paired with every chain it is valid on. `chains` is non-empty
/// and preserves ChainKit's canonical order; a single-format address (TON,
/// TRON, BTC) yields one chain, an EVM address yields all supported EVM chains.
public struct MultichainRecipientCandidates: Hashable, Codable, Sendable {
    public let address: String
    public let chains: [MultichainChain]

    public init(address: String, chains: [MultichainChain]) {
        self.address = address
        self.chains = chains
    }
}

public struct MultichainPublicKey: Hashable, Codable, Sendable {
    public let defaultHex: String
    public let segWit: String

    public init(defaultHex: String, segWit: String) {
        self.defaultHex = defaultHex
        self.segWit = segWit
    }
}

public struct MultichainWalletAddress: Hashable, Codable, Sendable {
    public let chain: MultichainChain
    public let address: String
    public let type: MultichainWalletAddressType?
    public let publicKey: MultichainPublicKey?

    public init(
        chain: MultichainChain,
        address: String,
        type: MultichainWalletAddressType? = nil,
        publicKey: MultichainPublicKey? = nil
    ) {
        self.chain = chain
        self.address = address
        self.type = type
        self.publicKey = publicKey
    }
}

public enum MultichainWalletSyncState: String, Hashable, Codable, Sendable {
    case pending
    case synced
    case failed
}

public struct MultichainWalletState: Hashable, Codable, Sendable {
    public let walletId: String
    public let addresses: [MultichainWalletAddress]
    public let syncState: MultichainWalletSyncState

    public init(
        walletId: String,
        addresses: [MultichainWalletAddress],
        syncState: MultichainWalletSyncState = .pending
    ) {
        self.walletId = walletId
        self.addresses = addresses
        self.syncState = syncState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        walletId = try container.decode(String.self, forKey: .walletId)
        addresses = try container.decode([MultichainWalletAddress].self, forKey: .addresses)
        syncState = try container.decodeIfPresent(MultichainWalletSyncState.self, forKey: .syncState) ?? .pending
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(walletId, forKey: .walletId)
        try container.encode(addresses, forKey: .addresses)
        try container.encode(syncState, forKey: .syncState)
    }

    enum CodingKeys: String, CodingKey {
        case walletId
        case addresses
        case syncState
    }
}

public enum MultichainWallet: Hashable, Sendable, Codable {
    case multichain(MultichainWalletState)
    case unavailable
}

public struct MultichainWalletChallenge: Hashable, Sendable {
    public let challenge: String
    public let expiresAt: Date

    public init(challenge: String, expiresAt: Date) {
        self.challenge = challenge
        self.expiresAt = expiresAt
    }
}

/// One entry of a `/api/v2/wallets/register` batch. The id carries its own format and kind and
/// the root key is recovered from the proof, so those two fields identify the wallet. The proof
/// binds the device id, so an item is only valid for the device session it was signed for.
public struct MultichainWalletRegisterItem: Hashable, Sendable {
    public let walletId: String
    public let walletProof: String
    public let accounts: [MultichainWalletAddress]

    public init(
        walletId: String,
        walletProof: String,
        accounts: [MultichainWalletAddress]
    ) {
        self.walletId = walletId
        self.walletProof = walletProof
        self.accounts = accounts
    }
}

/// Per-item outcome: items are verified independently, so one bad proof does not fail the batch.
public struct MultichainWalletRegisterResult: Hashable, Sendable {
    public let index: Int
    public let walletId: String?
    /// Machine-readable reason when the item failed; `nil` on success.
    public let error: String?

    public init(index: Int, walletId: String?, error: String?) {
        self.index = index
        self.walletId = walletId
        self.error = error
    }
}
