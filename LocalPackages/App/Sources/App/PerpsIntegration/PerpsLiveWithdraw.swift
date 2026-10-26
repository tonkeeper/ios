import Foundation
import KeeperCore
import PerpsModels
import TKLogging

@MainActor
final class PerpsLiveWithdraw: PerpsWithdrawing {
    /// The Perps balance itself, sent out without a swap.
    private static let direct = PerpsDepositService.targetAsset
    private static let destinationIds = [
        direct.assetId,
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
    /// Fixed when the user picks it: the listing behind the picker is read again on every
    /// open and may come back without it.
    private(set) var destination = PerpsDepositSource(
        assetId: direct.assetId,
        symbol: direct.symbol,
        decimals: direct.decimals,
        network: .ethereum
    )
    private var assets = [String: MultichainAsset]()

    init?(walletScope: PerpsWalletScope, assetBalanceProvider: MultichainAssetBalanceProvider, multichainService: any MultichainService) {
        guard let service = walletScope.withdrawService else { return nil }
        self.service = service
        accountStore = walletScope.accountStore
        wallet = walletScope.wallet
        self.assetBalanceProvider = assetBalanceProvider
        self.multichainService = multichainService
    }

    func availableDestinations() async -> [PerpsDepositSourceOption] {
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
            Log.perps.failure("Withdrawal destinations load failed wallet=\(state.walletId) cached=\(assets.count)", error: error)
            listed = Array(assets.values)
        }
        var byId = listed.reduce(into: [String: MultichainAsset]()) { assets, asset in
            assets[asset.asset.assetId.lowercased()] = asset
        }
        let missing = Self.destinationIds.filter { byId[$0.lowercased()] == nil }
        let loaded = await withTaskGroup(of: (String, MultichainAsset?).self) { [assetBalanceProvider, wallet] group in
            for id in missing {
                group.addTask { await(id, assetBalanceProvider.loadAsset(for: id, wallet: wallet, includingHidden: false)) }
            }
            return await group.reduce(into: [String: MultichainAsset]()) { loaded, pair in
                loaded[pair.0.lowercased()] = pair.1
            }
        }
        byId.merge(loaded) { listed, _ in listed }
        if !Task.isCancelled { assets = byId }
        var excluded = [String]()
        let options = Self.destinationIds.compactMap { id -> PerpsDepositSourceOption? in
            guard let asset = assets[id.lowercased()] else {
                excluded.append("\(id): asset unavailable or hidden")
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
                    amount: "0",
                    usdPrice: (asset.price.prices["USD"] ?? asset.price.prices["usd"]).map { Decimal($0) },
                    iconURL: URL(string: asset.asset.image)
                )
            )
        }
        Log.perps.i("Withdrawal destinations loaded wallet=\(state.walletId) count=\(options.count)", extraInfo: ["excluded": excluded.joined(separator: ","), "picker_asset_ids": options.map { $0.source.assetId }.joined(separator: ",")])
        return options
    }

    func selectDestination(assetId: String) {
        guard let asset = assets[assetId.lowercased()], let network = PerpsFundingNetwork(assetId: assetId) else { return }
        destination = PerpsDepositSource(assetId: asset.asset.assetId, symbol: asset.asset.symbol, decimals: asset.asset.decimals, network: network)
    }

    func loadBalance() async -> PerpsFundingBalance? {
        let selected = destination
        async let available = try? service.available()
        let asset: MultichainAsset? = if let cached = assets[selected.assetId.lowercased()] {
            cached
        } else {
            await assetBalanceProvider.loadAsset(for: selected.assetId, wallet: wallet, includingHidden: true)
        }
        guard let available = await available, destination == selected else { return nil }
        return PerpsFundingBalance(
            amount: available,
            usdPrice: 1,
            iconURL: asset.flatMap { URL(string: $0.asset.image) }
        )
    }

    func review(amount: String) async throws -> PerpsReviewedWithdraw {
        let selected = destination
        guard let chain = MultichainChain(assetId: selected.assetId),
              let recipient = wallet.multichainAddress(for: chain)
        else { throw PerpsLiveWithdrawError.destinationUnavailable }
        let review = try await service.review(
            destination: PerpsFundingAsset(assetId: selected.assetId, symbol: selected.symbol, decimals: selected.decimals),
            recipient: recipient,
            amount: amount
        )
        let price = assets[selected.assetId.lowercased()].flatMap { ($0.price.prices["USD"] ?? $0.price.prices["usd"]).map { Decimal($0) } }
        let feeUsd = review.estimatedTotalFeeUsd(destinationUsdPrice: price)
        let fee = review.receivesAtLeast ? feeUsd.map { value in
            var value = value
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 6, .up)
            return NSDecimalNumber(decimal: rounded).stringValue
        } : review.networkFee
        Log.perps.i("Withdrawal reviewed asset=\(selected.assetId) amount=\(review.amount) receive=\(review.receiveAmount)", extraInfo: ["lighter_fee_usdc": review.networkFee ?? "unknown", "estimated_total_fee_usd": fee ?? "unknown", "destination_usd_price": price.map { NSDecimalNumber(decimal: $0).stringValue } ?? "unknown"])
        return PerpsReviewedWithdraw(
            terms: PerpsWithdrawTerms(
                requestedAmount: amount,
                withdrawAmount: review.debitAmount,
                receiveAmount: review.receiveAmount,
                receivesAtLeast: review.receivesAtLeast,
                receiveSymbol: selected.symbol,
                networkFee: fee,
                networkFeeSymbol: "USDC",
                networkFeeUsd: feeUsd,
                expiresAt: review.expiresAt,
                withdrawalDelaySeconds: review.withdrawalDelaySeconds
            )
        ) { [service, accountStore] passcode in
            // Paying may register the trading key, which the store would otherwise still miss.
            defer { accountStore.refresh() }
            return try await service.pay(review: review, passcode: passcode)
        }
    }

    func message(for error: Error) -> PerpsWithdrawMessage {
        switch error {
        case PerpsWithdrawServiceError.belowMinimum:
            .belowMinimum(usdc: "1")
        case PerpsWithdrawServiceError.quoteExpired, PerpsWithdrawServiceError.feeChanged, PerpsWithdrawQuoteError.expired:
            .quoteExpired
        default:
            .failed
        }
    }
}

private enum PerpsLiveWithdrawError: Error {
    case destinationUnavailable
}
