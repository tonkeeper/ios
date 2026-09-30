import BigInt
import ChainKit
import Foundation
import MultichainAPI
import OpenAPIRuntime

extension MultichainChain {
    init?(api: MultichainAPI.Components.Schemas.Chain) {
        self.init(rawValue: api.rawValue)
    }

    func toAPIParametersChainPath() -> MultichainAPI.Components.Parameters.ChainPath {
        toAPISchemaChain()
    }

    func toAPISchemaChain() -> MultichainAPI.Components.Schemas.Chain {
        switch self {
        case .ton: .ton
        case .eth: .eth
        case .base: .base
        case .btc: .btc
        case .tron: .tron
        case .arb: .arb
        case .bsc: .bsc
        }
    }

    func toAPIParametersSearchChainQuery() -> MultichainAPI.Components.Parameters.SearchChainQuery {
        switch self {
        case .ton: .ton
        case .eth: .eth
        case .base: .base
        case .btc: .btc
        case .tron: .tron
        case .arb: .arb
        case .bsc: .bsc
        }
    }

    public func onrampDestinationChainPath(network: MultichainNetwork = .mainnet) -> String {
        "\(toAPISchemaChain().rawValue)/\(network.toAPISchemaNetwork().rawValue)"
    }

    /// The chain a multichain asset id should be badged with, or `nil` when it needs no badge
    /// (a chain's own primary coin). Lives here rather than in the UI layer because resolving it
    /// means parsing the id with ChainKit, and `KeeperCore.framework` is the only image allowed
    /// to link ChainKit.
    public static func badgeChain(forAssetId assetId: String) -> MultichainChain? {
        guard let asset = AssetCompanion.shared.coinFromString(assetId: assetId),
              let chain = MultichainChain(chainKitNetwork: asset.chain.network.type)
        else {
            return nil
        }
        guard asset is AssetCoin else {
            return chain
        }
        return asset.coin.primaryCoin != nil ? chain : nil
    }

    public init?(chainKitNetwork: ChainKit.Network.Type_) {
        switch chainKitNetwork {
        case .ethereum:
            self = .eth
        case .arbitrum:
            self = .arb
        case .base:
            self = .base
        case .bitcoin:
            self = .btc
        case .smartchain:
            self = .bsc
        case .tron:
            self = .tron
        case .ton:
            self = .ton
        default:
            return nil
        }
    }
}

extension MultichainNetwork {
    func toAPISchemaNetwork() -> MultichainAPI.Components.Schemas.Network {
        MultichainAPI.Components.Schemas.Network(rawValue: rawValue)!
    }
}

extension MultichainPendingTransaction {
    func toAPISchemaPendingTransaction() -> MultichainAPI.Components.Schemas.PendingTransaction {
        MultichainAPI.Components.Schemas.PendingTransaction(
            chain: chain.toAPISchemaChain(),
            network: network.toAPISchemaNetwork(),
            tx_hash: txHash,
            activity_type: activityType.toAPISchemaActivityType(),
            payload: activityType.toAPISchemaPayload()
        )
    }
}

extension MultichainPendingTransaction.ActivityType {
    func toAPISchemaActivityType() -> MultichainAPI.Components.Schemas.ActivityType {
        switch self {
        case .send: MultichainActivityType.send.rawValue
        case .swap: MultichainActivityType.swap.rawValue
        case .stake: MultichainActivityType.stake.rawValue
        case .unstake: MultichainActivityType.unstake.rawValue
        case .contractCall: MultichainActivityType.contractCall.rawValue
        }
    }

    func toAPISchemaPayload() -> MultichainAPI.Components.Schemas.PendingTransaction.payloadPayload? {
        guard case let .swap(details) = self else {
            return nil
        }
        var values: [String: (any Sendable)?] = [
            "from_asset_id": details.fromAssetId,
            "to_asset_id": details.toAssetId,
        ]
        if let quote = details.quote {
            values["aggregator"] = quote.aggregator
            values["route_id"] = quote.routeId
            if let providerRouteId = quote.providerRouteId {
                values["provider_route_id"] = providerRouteId
            }
        }
        var properties = OpenAPIRuntime.OpenAPIObjectContainer()
        properties.value = values
        return MultichainAPI.Components.Schemas.PendingTransaction.payloadPayload(
            additionalProperties: properties
        )
    }
}

extension MultichainWalletAddressType {
    /// The API now models `WalletAccount.type` as a free-form pattern string rather than a
    /// closed enum; `rawValue` already mirrors the wire values (`"v3R1"`, `"p2sh-p2wpkh"`, ...),
    /// so unrecognized values simply fail to parse instead of crashing.
    init?(api: String) {
        self.init(rawValue: api)
    }

    func toAPIWalletAccountType() -> String {
        rawValue
    }
}

extension MultichainWalletAddress {
    func toAPIWalletAccount() -> MultichainAPI.Components.Schemas.WalletAccount {
        MultichainAPI.Components.Schemas.WalletAccount(
            chain: chain.toAPISchemaChain(),
            address: address,
            _type: type?.toAPIWalletAccountType()
        )
    }
}

extension MultichainAssetCapability {
    func toAPICapabilitiesQueryPayload() -> MultichainAPI.Components.Parameters.CapabilitiesQueryPayload {
        switch self {
        case .onramp:
            .onramp
        case .offramp:
            .offramp
        case .swap:
            .swap
        case .p2p:
            .p2p
        }
    }
}

extension MultichainAssetVerification {
    init(api: MultichainAPI.Components.Schemas.AssetInfo.verificationPayload) {
        switch api {
        case .trusted:
            self = .trusted
        case .whitelist:
            self = .whitelist
        case .none:
            self = .none
        case .blacklist:
            self = .blacklist
        }
    }
}

extension MultichainAssetDetails {
    init(api: MultichainAPI.Components.Schemas.AssetInfo) {
        self.init(
            assetId: api.asset_id,
            chain: api.chain.flatMap { MultichainChain(assetIdChain: $0) },
            name: api.name,
            symbol: api.symbol,
            decimals: api.decimals,
            image: api.image,
            verification: MultichainAssetVerification(api: api.verification),
            capabilities: Set(
                (api.capabilities?.capabilities ?? []).compactMap(MultichainAssetCapability.init(rawValue:))
            )
        )
    }
}

extension MultichainAssetPrice {
    init(api: MultichainAPI.Components.Schemas.AssetPrice) {
        self.init(
            prices: api.prices?.additionalProperties ?? [:],
            diff24h: api.diff_24h?.additionalProperties ?? [:],
            diff7d: api.diff_7d?.additionalProperties ?? [:],
            diff30d: api.diff_30d?.additionalProperties ?? [:]
        )
    }
}

extension MultichainAsset {
    init(api: MultichainAPI.Components.Schemas.Asset) {
        self.init(
            asset: MultichainAssetDetails(api: api.asset),
            price: MultichainAssetPrice(api: api.price),
            isHidden: api.is_hidden,
            balance: BigUInt(api.balance) ?? .zero,
            marketCap: [:]
        )
    }

    init(api: MultichainAPI.Components.Schemas.SummaryAsset, balance: BigUInt) {
        self.init(
            asset: MultichainAssetDetails(api: api.asset),
            price: MultichainAssetPrice(api: api.price),
            balance: balance,
            marketCap: api.market_cap.additionalProperties
        )
    }
}

extension MultichainFeeEstimate {
    init(api: MultichainAPI.Components.Schemas.FeeEstimate) {
        self.init(slow: api.slow, normal: api.normal, fast: api.fast)
    }
}

extension MultichainBroadcastResult {
    init(api: MultichainAPI.Components.Responses.BroadcastResult.Body.jsonPayload) {
        self.init(txHash: api.txHash)
    }
}

extension MultichainWalletAccount {
    init?(api: MultichainAPI.Components.Schemas.WalletAccount) {
        guard let chain = MultichainChain(api: api.chain) else {
            return nil
        }
        self.init(
            chain: chain,
            address: api.address,
            type: api._type.flatMap(MultichainWalletAddressType.init(api:))
        )
    }
}

extension MultichainWalletChallenge {
    init(api: MultichainAPI.Components.Schemas.WalletChallenge) {
        self.init(
            challenge: api.challenge,
            expiresAt: api.expires_at
        )
    }

    init(api: MultichainAPI.Components.Schemas.AuthChallenge) {
        self.init(
            challenge: api.challenge,
            expiresAt: api.expires_at
        )
    }
}

extension MultichainRegisteredWallet {
    init(api: MultichainAPI.Components.Schemas.Wallet) {
        self.init(
            walletId: api.wallet_id,
            createdAt: api.created_at,
            accounts: api.accounts.compactMap { MultichainWalletAccount(api: $0) },
            syncStatus: MultichainWalletSyncStatus(api: api.sync_status)
        )
    }
}

extension MultichainWalletSyncStatus {
    init(api: MultichainAPI.Components.Schemas.SyncStatus) {
        var chains = [MultichainChain: MultichainChainSyncStatus]()
        for (rawChain, status) in api.chains.additionalProperties {
            guard let chain = MultichainChain(rawValue: rawChain) else {
                continue
            }
            chains[chain] = MultichainChainSyncStatus(api: status)
        }
        self.init(
            chains: chains
        )
    }
}

extension MultichainChainSyncStatus {
    init(api: MultichainAPI.Components.Schemas.ChainSyncStatus) {
        self.init(
            status: Status(api: api.status),
            balancesAt: api.balances_at,
            activityAt: api.activity_at,
            reason: api.reason.map { Reason(api: $0) },
            retryAfterMilliseconds: api.retry_after_ms,
            backfill: Backfill(api: api.backfill)
        )
    }
}

extension MultichainChainSyncStatus.Status {
    init(api: MultichainAPI.Components.Schemas.ChainSyncStatus.statusPayload) {
        switch api {
        case .ready:
            self = .ready
        case .in_progress:
            self = .inProgress
        case .failed:
            self = .failed
        }
    }
}

extension MultichainChainSyncStatus.Backfill {
    init(api: MultichainAPI.Components.Schemas.ChainSyncStatus.backfillPayload) {
        switch api {
        case .complete:
            self = .complete
        case .in_progress:
            self = .inProgress
        case .queued:
            self = .queued
        }
    }
}

extension MultichainChainSyncStatus.Reason {
    init(api: MultichainAPI.Components.Schemas.ChainSyncStatus.reasonPayload) {
        switch api {
        case .provider_timeout:
            self = .providerTimeout
        case .provider_5xx:
            self = .provider5xx
        case .rate_limited:
            self = .rateLimited
        case .circuit_open:
            self = .circuitOpen
        case .capability_not_supported:
            self = .capabilityNotSupported
        }
    }
}

extension MultichainActivity {
    init?(api: MultichainAPI.Components.Schemas.Activity) {
        let fromChain = MultichainChain(rawValue: api.from_chain)
        let toChain = MultichainChain(rawValue: api.to_chain)
        let isPerps = api.activity_type.hasPrefix(MultichainActivityType.perpsRawValuePrefix)
        guard isPerps || (fromChain != nil && toChain != nil) else {
            return nil
        }
        let activityType = MultichainActivityType(rawValue: api.activity_type) ?? .unknown
        let feeType = MultichainActivityFeeType(api: api.fee?._type ?? api.fee_type)
        self.init(
            activityType: activityType,
            status: MultichainActivityStatus(rawValue: api.status.rawValue)!,
            blockTime: api.block_time,
            blockNumber: api.block_number,
            fromChain: fromChain,
            toChain: toChain,
            walletAddress: api.wallet_address,
            direction: MultichainActivityDirection(api: api.direction),
            fromAddress: api.from_address,
            toAddress: api.to_address,
            outToken: api.out_token.map { MultichainAssetDetails(api: $0) },
            outAmount: api.out_amount,
            outAmountUsd: api.out_amount_usd,
            inToken: api.in_token.map { MultichainAssetDetails(api: $0) },
            inAmount: api.in_amount,
            inAmountUsd: api.in_amount_usd,
            feeToken: api.fee_token.map { MultichainAssetDetails(api: $0) },
            feeAmount: api.fee_amount,
            feeAmountUsd: api.fee_amount_usd,
            protocolName: api._protocol,
            txIds: api.tx_ids,
            explorerURL: api.explorer_url.flatMap(URL.init(string:)),
            isRead: api.is_read,
            isSpam: api.is_spam ?? false,
            comment: api.meta?.comment,
            tronResource: api.meta?.tronResource,
            feeType: feeType,
            batteryCharges: feeType == .battery
                ? Self.chargesCount(api.fee?.amount ?? api.fee_amount)
                : nil,
            perps: api.meta?.perps
        )
    }

    private static func chargesCount(_ amount: String?) -> Int? {
        guard let amount else {
            return nil
        }
        if let count = Int(amount) {
            return count
        }
        guard let value = Double(amount), value.isFinite else {
            return nil
        }
        return Int(exactly: value)
    }
}

extension MultichainActivityFeeType {
    init?(api: MultichainAPI.Components.Schemas.ActivityFeeType?) {
        switch api {
        case .gasless:
            self = .gasless
        case .native:
            self = .native
        case .battery:
            self = .battery
        case nil:
            return nil
        }
    }
}

private let iso8601FractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let iso8601Formatter = ISO8601DateFormatter()

private extension MultichainAPI.Components.Schemas.Activity.metaPayload {
    var comment: String? {
        guard let value = additionalProperties.value["comment"] else {
            return nil
        }
        return value as? String
    }

    var perps: MultichainActivityPerpsMeta? {
        guard let value = additionalProperties.value["perps"],
              let payload = value as? [String: (any Sendable)?]
        else {
            return nil
        }
        return MultichainActivityPerpsMeta(
            symbol: payload["symbol"].flatMap { $0 as? String },
            assetId: payload["asset_id"].flatMap { $0 as? String },
            side: payload["side"].flatMap { $0 as? String }.flatMap(MultichainPerpsSide.init(rawValue:)),
            closeReason: payload["reason"].flatMap { $0 as? String }
                .flatMap(MultichainPerpsCloseReason.init(rawValue:)),
            accountIndex: Self.int64Value(payload["account_index"] ?? nil),
            settledAt: payload["settled_at"].flatMap { $0 as? String }.flatMap(Self.date(fromISO8601:))
        )
    }

    var tronResource: MultichainTronResource? {
        guard let value = additionalProperties.value["tron_resource"],
              let resource = value as? [String: (any Sendable)?]
        else {
            return nil
        }
        let energy = Self.int64Value(resource["energy"] ?? nil) ?? 0
        let bandwidth = Self.int64Value(resource["bandwidth"] ?? nil) ?? 0
        guard energy > 0 || bandwidth > 0 else {
            return nil
        }
        return MultichainTronResource(energy: energy, bandwidth: bandwidth)
    }

    static func date(fromISO8601 value: String) -> Date? {
        iso8601FractionalFormatter.date(from: value) ?? iso8601Formatter.date(from: value)
    }

    static func int64Value(_ value: (any Sendable)?) -> Int64? {
        switch value {
        case let int as Int:
            return Int64(int)
        case let int64 as Int64:
            return int64
        case let double as Double:
            return Int64(exactly: double.rounded(.towardZero))
        default:
            return nil
        }
    }
}

extension MultichainActivityDirection {
    init(api: MultichainAPI.Components.Schemas.ActivityDirection) {
        switch api {
        case ._in:
            self = .incoming
        case .out:
            self = .outgoing
        case ._self:
            self = .selfTransfer
        }
    }
}

extension MultichainAssetSearchSort {
    func toAPIParametersSort() -> MultichainAPI.Components.Parameters.SortQuery {
        switch self {
        case .marketCap: return .market_cap
        case .volume: return .volume
        case .priceDiffAsc: return .price_diff_asc
        case .priceDiffDesc: return .price_diff_desc
        }
    }
}

extension MultichainAssetFilterAction {
    func toAPIRequestAction() -> MultichainAPI.Components.RequestBodies.SetAssetFilters
        .jsonPayload
        .changesPayloadPayload
        .actionPayload
    {
        switch self {
        case .show:
            return .show
        case .hide:
            return .hide
        }
    }
}
