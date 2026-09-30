@preconcurrency import BigInt
import Foundation

// MARK: - Common

public struct MultichainHealth: Equatable, Sendable {
    public let ok: Bool

    public init(ok: Bool) {
        self.ok = ok
    }
}

public enum MultichainNetwork: String, Sendable, Equatable, Codable {
    case mainnet
    case testnet
}

public extension MultichainNetwork {
    init(walletNetwork: Network) {
        self = walletNetwork.isMainnet ? .mainnet : .testnet
    }
}

// MARK: - Assets

public enum MultichainAssetVerification: String, Hashable, Sendable, Codable {
    case trusted
    case whitelist
    case none
    case blacklist
}

public enum MultichainAssetCapability: String, Hashable, Sendable, Codable {
    case onramp
    case offramp
    case swap
    case p2p
}

public struct MultichainAssetDetails: Hashable, Sendable, Codable {
    public let assetId: String
    public let chain: MultichainChain?
    public let name: String
    public let symbol: String
    public let decimals: Int
    public let image: String
    public let verification: MultichainAssetVerification
    public let capabilities: Set<MultichainAssetCapability>

    public var isVerified: Bool {
        switch verification {
        case .trusted, .whitelist:
            true
        case .none, .blacklist:
            false
        }
    }

    public var isTrusted: Bool {
        verification == .trusted
    }

    public var isUnverified: Bool {
        !isVerified
    }

    public var isScam: Bool {
        verification == .blacklist
    }

    public init(
        assetId: String,
        chain: MultichainChain? = nil,
        name: String,
        symbol: String,
        decimals: Int,
        image: String,
        verification: MultichainAssetVerification = .none,
        capabilities: Set<MultichainAssetCapability> = []
    ) {
        self.assetId = assetId
        self.chain = chain ?? AssetIdComponents(assetId: assetId).flatMap {
            MultichainChain(assetIdChain: $0.chain)
        }
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.image = image
        self.verification = verification
        self.capabilities = capabilities
    }
}

public struct MultichainAssetPrice: Equatable, Sendable, Codable {
    public let prices: [String: Double]
    public let diff24h: [String: String]
    public let diff7d: [String: String]
    public let diff30d: [String: String]

    public init(
        prices: [String: Double],
        diff24h: [String: String],
        diff7d: [String: String],
        diff30d: [String: String]
    ) {
        self.prices = prices
        self.diff24h = diff24h
        self.diff7d = diff7d
        self.diff30d = diff30d
    }
}

public struct MultichainAsset: Equatable, Sendable, Codable {
    public let asset: MultichainAssetDetails
    public let price: MultichainAssetPrice
    public let isHidden: Bool
    public let balance: BigUInt
    public let marketCap: [String: String]

    public init(
        asset: MultichainAssetDetails,
        price: MultichainAssetPrice,
        isHidden: Bool = false,
        balance: BigUInt,
        marketCap: [String: String] = [:]
    ) {
        self.asset = asset
        self.price = price
        self.isHidden = isHidden
        self.balance = balance
        self.marketCap = marketCap
    }
}

public struct MultichainNativeFeeShortage: Hashable, Sendable {
    public let asset: MultichainAssetDetails
    public let requiredAmount: BigUInt

    public init(asset: MultichainAssetDetails, requiredAmount: BigUInt) {
        self.asset = asset
        self.requiredAmount = requiredAmount
    }
}

public extension MultichainAssetDetails {
    var isNative: Bool {
        guard case .coin = AssetIdComponents(assetId: assetId) else {
            return false
        }
        return true
    }
}

public extension MultichainAsset {
    var isNative: Bool {
        asset.isNative
    }
}

public enum MultichainAssetSearchSort: String, Sendable, Equatable {
    case marketCap = "market_cap"
    case volume
    case priceDiffAsc = "price_diff_asc"
    case priceDiffDesc = "price_diff_desc"
}

public enum MultichainAssetFilterAction: String, Sendable, Equatable, Codable {
    case show
    case hide
}

public struct MultichainAssetFilterChange: Equatable, Sendable {
    public let assetId: String
    public let action: MultichainAssetFilterAction

    public init(assetId: String, action: MultichainAssetFilterAction) {
        self.assetId = assetId
        self.action = action
    }
}

public struct MultichainAccount: Equatable, Sendable {
    public let chain: MultichainChain
    public let network: MultichainNetwork?
    public let address: String

    public init(chain: MultichainChain, network: MultichainNetwork?, address: String) {
        self.chain = chain
        self.network = network
        self.address = address
    }
}

// MARK: - Fees & broadcast

public struct MultichainFeeEstimate: Equatable, Sendable {
    public let slow: String
    public let normal: String
    public let fast: String

    public init(slow: String, normal: String, fast: String) {
        self.slow = slow
        self.normal = normal
        self.fast = fast
    }
}

public struct MultichainBroadcastResult: Equatable, Sendable {
    public let txHash: String

    public init(txHash: String) {
        self.txHash = txHash
    }
}

public struct MultichainWalletAccount: Equatable, Sendable {
    public let chain: MultichainChain
    public let address: String
    public let type: MultichainWalletAddressType?

    public init(chain: MultichainChain, address: String, type: MultichainWalletAddressType? = nil) {
        self.chain = chain
        self.address = address
        self.type = type
    }
}

public struct MultichainRegisteredWallet: Equatable, Sendable {
    public let walletId: String
    public let createdAt: Date
    public let accounts: [MultichainWalletAccount]
    public let syncStatus: MultichainWalletSyncStatus?

    public init(
        walletId: String,
        createdAt: Date,
        accounts: [MultichainWalletAccount],
        syncStatus: MultichainWalletSyncStatus? = nil
    ) {
        self.walletId = walletId
        self.createdAt = createdAt
        self.accounts = accounts
        self.syncStatus = syncStatus
    }
}

public struct MultichainWalletSyncStatus: Equatable, Sendable {
    public let chains: [MultichainChain: MultichainChainSyncStatus]

    public init(chains: [MultichainChain: MultichainChainSyncStatus]) {
        self.chains = chains
    }

    public var requiresPolling: Bool {
        chains.values.contains {
            $0.status == .inProgress || ($0.status == .ready && $0.backfill != .complete)
        }
    }
}

public struct MultichainChainSyncStatus: Equatable, Sendable {
    public enum Status: String, Sendable, Equatable {
        case ready
        case inProgress = "in_progress"
        case failed
    }

    public enum Backfill: String, Sendable, Equatable {
        case complete
        case inProgress = "in_progress"
        case queued
    }

    public enum Reason: String, Sendable, Equatable {
        case providerTimeout = "provider_timeout"
        case provider5xx = "provider_5xx"
        case rateLimited = "rate_limited"
        case circuitOpen = "circuit_open"
        case capabilityNotSupported = "capability_not_supported"
    }

    public let status: Status
    public let balancesAt: Date?
    public let activityAt: Date?
    public let reason: Reason?
    public let retryAfterMilliseconds: Int?
    public let backfill: Backfill

    public init(
        status: Status,
        balancesAt: Date?,
        activityAt: Date?,
        reason: Reason?,
        retryAfterMilliseconds: Int?,
        backfill: Backfill
    ) {
        self.status = status
        self.balancesAt = balancesAt
        self.activityAt = activityAt
        self.reason = reason
        self.retryAfterMilliseconds = retryAfterMilliseconds
        self.backfill = backfill
    }
}

public struct MultichainWalletAssetsPage: Equatable, Sendable {
    public let assets: [MultichainAsset]
    public let nextCursor: String?
    /// Fiat portfolio totals per currency code (e.g. USD).
    public let fiatPrice: [String: String]

    public init(assets: [MultichainAsset], nextCursor: String?, fiatPrice: [String: String]) {
        self.assets = assets
        self.nextCursor = nextCursor
        self.fiatPrice = fiatPrice
    }
}

// MARK: - Activities

public enum MultichainActivityType: String, Sendable, Equatable, Codable, CaseIterable {
    case send
    case receive
    case swap
    case approve
    case revoke
    case bridge
    case stake
    case unstake
    case claim
    case wrap
    case unwrap
    case deploy
    case contractCall = "contract_call"
    case nftPurchase = "nft_purchase"
    case auctionBid = "auction_bid"
    case mint
    case burn
    case dnsRenew = "dns_renew"
    case subscribe
    case unsubscribe
    case freeze
    case unfreeze
    case delegate
    case undelegate
    case vote
    case supply
    case withdraw
    case borrow
    case repay
    case airdrop
    case perpsPositionOpened = "perps.position_opened"
    case perpsPositionClosed = "perps.position_closed"
    case perpsBalanceDeposit = "perps.balance_deposit"
    case perpsBalanceWithdrawal = "perps.balance_withdrawal"
    /// Fallback for activity types the client doesn't recognize yet — keeps unknown
    /// values decodable and rendered (by direction) instead of dropping or crashing.
    case unknown
}

public enum MultichainActivityStatus: String, Sendable, Equatable, Codable {
    case pending
    case confirmed
    case failed
    case dropped
}

public enum MultichainActivityDirection: String, Sendable, Equatable, Codable {
    case incoming = "in"
    case outgoing = "out"
    case selfTransfer = "self"
}

public enum MultichainActivityFeeType: String, Sendable, Hashable {
    case gasless
    case native
    case battery
}

/// TRON energy/bandwidth consumed by an activity, from `meta.tron_resource`.
/// Used when the transfer was sponsored (e.g. Battery) and there is no burned TRX fee.
public struct MultichainTronResource: Hashable, Sendable {
    public let energy: Int64
    public let bandwidth: Int64

    public init(energy: Int64, bandwidth: Int64) {
        self.energy = energy
        self.bandwidth = bandwidth
    }
}

public extension MultichainActivityType {
    static let perpsRawValuePrefix = "perps."

    var isPerps: Bool {
        switch self {
        case .perpsPositionOpened, .perpsPositionClosed, .perpsBalanceDeposit, .perpsBalanceWithdrawal:
            true
        default:
            false
        }
    }
}

public enum MultichainActivityTypeFilter: String, Sendable, Equatable {
    case send
    case receive
    case swap
    case perps
}

public enum MultichainPerpsSide: String, Sendable, Equatable {
    case long
    case short
}

public enum MultichainPerpsCloseReason: String, Sendable, Equatable {
    case manual
    case takeProfit = "take_profit"
    case stopLoss = "stop_loss"
    case liquidation
}

public struct MultichainActivityPerpsMeta: Hashable, Sendable {
    public let symbol: String?
    public let assetId: String?
    public let side: MultichainPerpsSide?
    public let closeReason: MultichainPerpsCloseReason?
    public let accountIndex: Int64?
    public let settledAt: Date?

    public init(
        symbol: String?,
        assetId: String?,
        side: MultichainPerpsSide?,
        closeReason: MultichainPerpsCloseReason?,
        accountIndex: Int64?,
        settledAt: Date?
    ) {
        self.symbol = symbol
        self.assetId = assetId
        self.side = side
        self.closeReason = closeReason
        self.accountIndex = accountIndex
        self.settledAt = settledAt
    }
}

public struct MultichainActivity: Hashable, Sendable {
    public let activityType: MultichainActivityType
    public let status: MultichainActivityStatus
    public let blockTime: Date
    public let blockNumber: Int64?
    public let fromChain: MultichainChain?
    public let toChain: MultichainChain?
    public let walletAddress: String?
    public let direction: MultichainActivityDirection
    public let fromAddress: String?
    public let toAddress: String?
    public let outToken: MultichainAssetDetails?
    public let outAmount: String?
    public let outAmountUsd: Double?
    public let inToken: MultichainAssetDetails?
    public let inAmount: String?
    public let inAmountUsd: Double?
    public let feeToken: MultichainAssetDetails?
    public let feeAmount: String?
    public let feeAmountUsd: Double?
    public let protocolName: String?
    public let txIds: [String]
    public let explorerURL: URL?
    public let isRead: Bool?
    public let isSpam: Bool
    public let comment: String?
    public let tronResource: MultichainTronResource?
    public let feeType: MultichainActivityFeeType?
    /// Keeper Battery charges spent on the fee. `0` is a real value; `nil` means the backend did not report it.
    public let batteryCharges: Int?
    public let perps: MultichainActivityPerpsMeta?

    public init(
        activityType: MultichainActivityType,
        status: MultichainActivityStatus,
        blockTime: Date,
        blockNumber: Int64?,
        fromChain: MultichainChain?,
        toChain: MultichainChain?,
        walletAddress: String?,
        direction: MultichainActivityDirection,
        fromAddress: String?,
        toAddress: String?,
        outToken: MultichainAssetDetails?,
        outAmount: String?,
        outAmountUsd: Double?,
        inToken: MultichainAssetDetails?,
        inAmount: String?,
        inAmountUsd: Double?,
        feeToken: MultichainAssetDetails?,
        feeAmount: String?,
        feeAmountUsd: Double?,
        protocolName: String?,
        txIds: [String],
        explorerURL: URL? = nil,
        isRead: Bool?,
        isSpam: Bool = false,
        comment: String? = nil,
        tronResource: MultichainTronResource? = nil,
        feeType: MultichainActivityFeeType? = nil,
        batteryCharges: Int? = nil,
        perps: MultichainActivityPerpsMeta? = nil
    ) {
        self.activityType = activityType
        self.status = status
        self.blockTime = blockTime
        self.blockNumber = blockNumber
        self.fromChain = fromChain
        self.toChain = toChain
        self.walletAddress = walletAddress
        self.direction = direction
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.outToken = outToken
        self.outAmount = outAmount
        self.outAmountUsd = outAmountUsd
        self.inToken = inToken
        self.inAmount = inAmount
        self.inAmountUsd = inAmountUsd
        self.feeToken = feeToken
        self.feeAmount = feeAmount
        self.feeAmountUsd = feeAmountUsd
        self.protocolName = protocolName
        self.txIds = txIds
        self.explorerURL = explorerURL
        self.isRead = isRead
        self.isSpam = isSpam
        self.comment = comment
        self.tronResource = tronResource
        self.feeType = feeType
        self.batteryCharges = batteryCharges
        self.perps = perps
    }
}

public struct MultichainWalletActivitiesPage: Equatable, Sendable {
    public let activities: [MultichainActivity]
    public let nextCursor: String?

    public init(activities: [MultichainActivity], nextCursor: String?) {
        self.activities = activities
        self.nextCursor = nextCursor
    }
}
