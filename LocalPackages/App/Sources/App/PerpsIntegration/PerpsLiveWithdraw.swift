import Foundation
import KeeperCore
import PerpsModels
import TKLogging

@MainActor
final class PerpsLiveWithdraw: PerpsWithdrawing {
    private static let defaultDestination = PerpsDepositService.targetAsset
    private static let destinationIds = [
        defaultDestination.assetId,
        "ton/mainnet/coin",
        "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
        "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955",
        "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
        "arb/mainnet/erc20/0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
        "base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
        "base/mainnet/erc20/0xfde4c96c8593536e31f229ea8f37b2ada2699bb2",
        "arb/mainnet/erc20/0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "bsc/mainnet/bep20/0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",
        "eth/mainnet/coin",
        "base/mainnet/coin",
        "arb/mainnet/coin",
        "bsc/mainnet/coin",
        "tron/mainnet/coin",
        "btc/mainnet/coin",
    ]

    private let service: PerpsWithdrawService
    private let accountStore: PerpsAccountStore
    private let wallet: Wallet
    private let assetBalanceProvider: MultichainAssetBalanceProvider
    private let multichainService: any MultichainService
    private let icons: PerpsFundingIconLoader
    private var destinations = [PerpsDepositSourceOption]()
    /// Fixed when the user picks it: the listing behind the picker is read again on every
    /// open and may come back without it.
    private(set) var destination = PerpsDepositSource(
        assetId: defaultDestination.assetId,
        symbol: defaultDestination.symbol,
        decimals: defaultDestination.decimals,
        network: .ethereum
    )
    private var assets = [String: MultichainAsset]()

    init?(walletScope: PerpsWalletScope, assetBalanceProvider: MultichainAssetBalanceProvider, multichainService: any MultichainService, assetDetailsService: any TradingAssetDetailsService) {
        guard let service = walletScope.withdrawService else { return nil }
        self.service = service
        accountStore = walletScope.accountStore
        wallet = walletScope.wallet
        self.assetBalanceProvider = assetBalanceProvider
        self.multichainService = multichainService
        icons = PerpsFundingIconLoader { id in
            let cached = await assetDetailsService.assetDetails(for: id)
            let details = if let cached { cached } else { try? await assetDetailsService.loadAssetDetails(id: id) }
            return details?.assetInfo.imageURL
        }
    }

    func availableDestinations() async -> [PerpsDepositSourceOption] {
        return await PerpsOperationLog.step("assets", source: "backend", fields: operationLogFields) {
            guard let state = wallet.multichainWalletState else { return [] }
            let listed: [MultichainAsset]
            do {
                listed = try await multichainService.getAllWalletAssets(
                    state: state,
                    currencies: ["usd"],
                    capabilities: nil,
                    chain: nil,
                    search: nil,
                    availableOnly: nil,
                    showHidden: false,
                    showAll: nil,
                    hideDust: nil
                ).assets
            } catch {
                PerpsOperationLog.event("assets", outcome: "failed", source: "backend", error: error, fields: ["cached_count": String(assets.count)])
                listed = Array(assets.values)
            }
            var byId = listed.reduce(into: [String: MultichainAsset]()) { assets, asset in
                assets[asset.asset.assetId.lowercased()] = asset
            }
            let missing = Self.destinationIds.filter { byId[$0.lowercased()] == nil }
            // The listing holds only the assets the wallet shows; a destination needs no balance.
            let loaded = await withTaskGroup(of: (String, MultichainAsset?).self) { [assetBalanceProvider, multichainService, wallet] group in
                for id in missing {
                    group.addTask {
                        let asset = try? await multichainService.getWalletAssetIncludingUnheld(state: state, assetId: id, currencies: ["usd"])
                        return (id, asset ?? assetBalanceProvider.cachedAsset(for: id, wallet: wallet))
                    }
                }
                return await group.reduce(into: [String: MultichainAsset]()) { loaded, pair in
                    loaded[pair.0.lowercased()] = pair.1
                }
            }
            byId.merge(loaded) { listed, _ in listed }
            guard !Task.isCancelled else { return [] }
            assets = byId
            var excluded = [String]()
            let options = Self.destinationIds.compactMap { id -> PerpsDepositSourceOption? in
                guard let asset = assets[id.lowercased()] else {
                    excluded.append("\(id): asset unavailable")
                    return nil
                }
                guard let network = PerpsFundingNetwork(assetId: id), let chain = MultichainChain(assetId: id) else {
                    excluded.append("\(id): unsupported network")
                    return nil
                }
                guard wallet.multichainAddress(for: chain) != nil else {
                    excluded.append("\(id): wallet address unavailable")
                    return nil
                }
                return PerpsDepositSourceOption(
                    source: PerpsDepositSource(assetId: asset.asset.assetId, symbol: asset.asset.symbol, decimals: asset.asset.decimals, network: network),
                    balance: PerpsFundingBalance(
                        amount: NSDecimalNumber.fromBigUInt(value: asset.balance, decimals: asset.asset.decimals).stringValue,
                        usdPrice: (asset.price.prices["USD"] ?? asset.price.prices["usd"]).map { Decimal($0) },
                        iconURL: PerpsFundingIconLoader.walletIconURL(asset.asset.image)
                    )
                )
            }.sortedByHoldingValue
            PerpsOperationLog.event("assets", outcome: "loaded", source: "backend", fields: ["excluded": excluded.joined(separator: ","), "picker_asset_ids": options.map { $0.source.assetId }.joined(separator: ",")])
            destinations = options
            return options
        }
    }

    func loadDestination() async -> PerpsDepositSourceOption? {
        let selected = destination
        let options = destinations.isEmpty ? await availableDestinations() : destinations
        guard !Task.isCancelled, destination == selected else { return nil }
        return options.first { $0.source.assetId.lowercased() == selected.assetId.lowercased() }
    }

    func selectDestination(assetId: String) {
        guard let option = destinations.first(where: { $0.source.assetId.lowercased() == assetId.lowercased() }) else { return }
        destination = option.source
    }

    private var operationLogFields: [String: String] {
        ["flow": "withdraw", "wallet_id": wallet.multichainWalletState?.walletId ?? wallet.id,
         "asset_id": destination.assetId, "chain": String(destination.assetId.split(separator: "/").first ?? "unknown")]
    }

    func loadBalance() async -> PerpsFundingBalance? {
        return await PerpsOperationLog.step("balance", source: "backend", fields: operationLogFields) {
            let selected = destination
            guard let available = try? await service.available(), !Task.isCancelled, destination == selected else { return nil }
            return PerpsFundingBalance(
                amount: available,
                usdPrice: 1,
                iconURL: nil
            )
        }
    }

    func loadIcon(assetId: String) async -> URL? {
        let asset = await asset(assetId: assetId)
        guard !Task.isCancelled else { return nil }
        return await icons.iconURL(assetId: assetId, walletImage: asset?.asset.image)
    }

    private func asset(assetId: String) async -> MultichainAsset? {
        if let cached = assets[assetId.lowercased()] {
            return cached
        }
        return await assetBalanceProvider.loadAsset(for: assetId, wallet: wallet, includingHidden: true)
    }

    func review(amount: String) async throws -> PerpsReviewedWithdraw {
        return try await PerpsOperationLog.step("review", source: "client", fields: operationLogFields.merging(["amount": amount]) { _, new in new }) {
            let selected = destination
            guard let chain = MultichainChain(assetId: selected.assetId),
                  let recipient = wallet.multichainAddress(for: chain)
            else {
                PerpsOperationLog.event("recipient_address", outcome: "unavailable", source: "wallet", fields: operationLogFields)
                throw PerpsLiveWithdrawError.destinationUnavailable
            }
            async let priced = asset(assetId: selected.assetId)
            let review = try await service.review(
                destination: PerpsFundingAsset(assetId: selected.assetId, symbol: selected.symbol, decimals: selected.decimals),
                recipient: recipient,
                amount: amount
            )
            let price = await priced.flatMap { ($0.price.prices["USD"] ?? $0.price.prices["usd"]).map { Decimal($0) } }
            let feeUsd = review.estimatedTotalFeeUsd(destinationUsdPrice: price)
            let fee = feeUsd.map { value in
                var value = value
                var rounded = Decimal()
                NSDecimalRound(&rounded, &value, 6, .up)
                return NSDecimalNumber(decimal: rounded).stringValue
            }
            PerpsOperationLog.event("review", outcome: "ready", fields: ["lighter_fee_usdc": review.networkFee, "estimated_total_fee_usd": fee ?? "unknown", "destination_usd_price": price.map { NSDecimalNumber(decimal: $0).stringValue } ?? "unknown"])
            return PerpsReviewedWithdraw(
                terms: PerpsWithdrawTerms(
                    requestedAmount: amount,
                    withdrawAmount: review.debitAmount,
                    receiveAmount: review.receiveAmount,
                    receivesAtLeast: true,
                    receiveSymbol: selected.symbol,
                    networkFee: fee,
                    networkFeeSymbol: "USDC",
                    networkFeeUsd: feeUsd,
                    expiresAt: review.expiresAt,
                    estimatedDurationSeconds: review.estimatedDurationSeconds,
                    recipientAddress: MultichainAddressFormatter.shortAddress(recipient, chain: chain),
                    provider: PerpsWithdrawReview.provider
                )
            ) { [service, accountStore, logContext = PerpsOperationLog.context] passcode in
                // Paying may register the trading key, which the store would otherwise still miss.
                defer { accountStore.refresh() }
                return try await PerpsOperationLog.$context.withValue(logContext) {
                    try await service.pay(review: review, passcode: passcode)
                }
            }
        }
    }

    func message(for error: Error) -> PerpsWithdrawMessage {
        PerpsWithdrawService.message(for: error)
    }
}

private enum PerpsLiveWithdrawError: Error, PerpsOperationLoggableError {
    var operationLogSource: String {
        "wallet"
    }

    case destinationUnavailable
}
