import BigInt
import Foundation
import KeeperCore
import PerpsModels
import TKLogging

@MainActor
final class PerpsLiveDeposit: PerpsDepositing {
    let walletName: String

    private let service: PerpsDepositService
    private let accountService: PerpsAccountService
    private let address: String
    private let wallet: Wallet
    private let assetBalanceProvider: MultichainAssetBalanceProvider
    private let multichainService: any MultichainService
    private(set) var source = PerpsLiveDeposit.depositSource(PerpsDepositService.targetAsset, on: .ethereum)
    private var selectableSources = [(asset: MultichainAsset, source: PerpsDepositSource)]()
    private var assetLoads = [String: Task<MultichainAsset?, Never>]()

    init?(
        walletScope: PerpsWalletScope,
        assetBalanceProvider: MultichainAssetBalanceProvider,
        multichainService: any MultichainService
    ) {
        guard let service = walletScope.depositService,
              let address = walletScope.wallet.multichainAddress(for: .eth)
        else { return nil }
        self.service = service
        accountService = walletScope.accountService
        self.address = address
        self.assetBalanceProvider = assetBalanceProvider
        self.multichainService = multichainService
        let wallet = walletScope.wallet
        self.wallet = wallet
        walletName = if case let .emoji(emoji) = wallet.icon { "\(emoji) \(wallet.label)" } else { wallet.label }
    }

    var holdsTradingKey: Bool {
        accountService.holdsKeptTradingKey(wallet: wallet)
    }

    func keepTradingKey(passcode: String) async -> Bool {
        await accountService.keepTradingKey(wallet: wallet, passcode: passcode)
    }

    func loadBalance() async -> PerpsFundingBalance? {
        let selected = source
        guard let asset = await loadListedAsset(selected.assetId), source == selected else { return nil }
        return PerpsFundingBalance(
            amount: Self.decimal(units: asset.balance, decimals: asset.asset.decimals).description,
            usdPrice: Self.usdPrice(of: asset),
            iconURL: URL(string: asset.asset.image)
        )
    }

    func loadMinimum() async -> PerpsDepositMinimum? {
        let selected = source
        guard let chain = PerpsDepositService.fundingChain(assetId: selected.assetId),
              let sender = wallet.multichainAddress(for: chain),
              let price = await loadAsset(selected.assetId).flatMap({ Self.usdPrice(of: $0) }),
              let minimum = await service.minimum(
                  sourceAsset: PerpsFundingAsset(assetId: selected.assetId, symbol: selected.symbol, decimals: selected.decimals),
                  usdPrice: price,
                  senderAddress: sender,
                  beneficiary: address
              ),
              source == selected
        else { return nil }
        return PerpsDepositMinimum(usd: minimum.usd, amount: Self.decimal(units: minimum.units, decimals: selected.decimals))
    }

    func loadLimit() async -> String? {
        let selected = source
        guard let asset = await loadAsset(selected.assetId), source == selected else { return nil }
        let balance = Self.decimal(units: asset.balance, decimals: asset.asset.decimals)
        guard balance > 0, asset.isNative else { return balance.description }
        var belowMinimum: String?
        let estimated = await Self.nativeLimit(balance: balance, decimals: asset.asset.decimals) { [weak self] amount in
            guard let self, self.source == selected else { return nil }
            do {
                let fee = try await self.quoteReview(amount: amount, registeringKey: false).networkFee.flatMap(Self.decimal)
                return self.source == selected ? fee : nil
            } catch {
                if belowMinimum == nil, case .belowMinimum = self.message(for: error) { belowMinimum = amount }
                return nil
            }
        }
        guard estimated == nil, source == selected else { return estimated }
        // Max stays usable when its fee cannot be priced: review then names what stops the amount —
        // the minimum, the balance or the fee.
        if let belowMinimum { return belowMinimum }
        // An unpriced TON fee still fits the swap's fixed reserve; other chains have no such bound.
        let reserved = asset.asset.chain == .ton
            ? Self.decimal(units: MultichainSwapMaxAmount.maxSwapInputAmount(for: asset), decimals: asset.asset.decimals)
            : 0
        return (reserved > 0 ? reserved : balance).description
    }

    func availableSources() async -> [PerpsDepositSourceOption] {
        guard let state = wallet.multichainWalletState else { return [PerpsDepositSourceOption(source: source, balance: await loadBalance())] }
        var assets: [MultichainAsset]
        do {
            assets = try await multichainService.getAllWalletAssets(
                state: state,
                currencies: ["usd"],
                capabilities: [.perpDeposit],
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                showAll: nil,
                hideDust: nil
            ).assets
        } catch {
            Log.perps.failure("Deposit sources load failed wallet=\(state.walletId) cached=\(selectableSources.count)", error: error)
            if !selectableSources.isEmpty || Task.isCancelled { return sourceOptions }
            assets = []
        }
        guard !Task.isCancelled else { return sourceOptions }
        let returnedIds = assets.map { $0.asset.assetId }
        if !assets.contains(where: { $0.asset.assetId.lowercased() == PerpsDepositService.targetAsset.assetId }),
           let direct = await loadListedAsset(PerpsDepositService.targetAsset.assetId)
        {
            assets.insert(direct, at: 0)
        }
        guard !Task.isCancelled else { return sourceOptions }
        // The listing is the backend's: one asset may come back twice, and the picker keys
        // its rows by id.
        var seen = Set<String>()
        var unsupportedIds = [String]()
        let fundable = assets.compactMap { asset -> (asset: MultichainAsset, source: PerpsDepositSource)? in
            guard let chain = PerpsDepositService.fundingChain(assetId: asset.asset.assetId) else {
                unsupportedIds.append(asset.asset.assetId)
                return nil
            }
            guard seen.insert(asset.asset.assetId.lowercased()).inserted else { return nil }
            let network = PerpsFundingNetwork(chain)
            let fundingAsset = PerpsFundingAsset(assetId: asset.asset.assetId, symbol: asset.asset.symbol, decimals: asset.asset.decimals)
            return (asset, Self.depositSource(fundingAsset, on: network))
        }
        selectableSources = fundable
        Log.perps.i("Deposit sources loaded wallet=\(state.walletId) count=\(selectableSources.count)", extraInfo: ["returned_asset_ids": returnedIds.joined(separator: ","), "unsupported_asset_ids": unsupportedIds.joined(separator: ","), "picker_asset_ids": selectableSources.map { $0.source.assetId }.joined(separator: ",")])
        return sourceOptions
    }

    private var sourceOptions: [PerpsDepositSourceOption] {
        selectableSources.map { asset, source in
            PerpsDepositSourceOption(
                source: source,
                balance: PerpsFundingBalance(
                    amount: Self.decimal(units: asset.balance, decimals: asset.asset.decimals).description,
                    usdPrice: Self.usdPrice(of: asset),
                    iconURL: URL(string: asset.asset.image)
                )
            )
        }
    }

    func selectSource(assetId: String) {
        guard let selected = selectableSource(assetId) else { return }
        source = selected.source
    }

    private func selectableSource(_ assetId: String) -> (asset: MultichainAsset, source: PerpsDepositSource)? {
        selectableSources.first { $0.source.assetId.lowercased() == assetId.lowercased() }
    }

    func review(amount: String) async throws -> PerpsReviewedDeposit {
        try await makeReviewed(quoteReview(amount: amount))
    }

    private func quoteReview(amount: String, registeringKey: Bool = true) async throws -> PerpsDepositReview {
        guard let chain = PerpsDepositService.fundingChain(assetId: source.assetId),
              let sender = wallet.multichainAddress(for: chain)
        else { throw PerpsLiveDepositError.sourceAddressUnavailable }
        return try await service.review(
            sourceAsset: PerpsFundingAsset(assetId: source.assetId, symbol: source.symbol, decimals: source.decimals),
            amount: amount,
            senderAddress: sender,
            beneficiary: address,
            registeringKey: registeringKey
        )
    }

    func pendingReview() async throws -> PerpsReviewedDeposit? {
        guard let review = try await service.pendingReview() else {
            return nil
        }
        let network = PerpsFundingNetwork(review.sourceChain)
        source = Self.depositSource(review.sourceAsset, on: network)
        return try await makeReviewed(review)
    }

    private func makeReviewed(_ review: PerpsDepositReview) async throws -> PerpsReviewedDeposit {
        let nativePrice = try await checkNetworkFee(review, fee: review.networkFee)
        Log.i(
            "🪵 Perps deposit: reviewed \(review.sourceAmount) \(review.sourceAsset.symbol) → \(review.creditedAmount) USDC"
                + " fee=\(review.networkFee ?? "nil") \(review.networkFeeSymbol) resumes=\(review.resumesPayment)"
        )
        let terms = PerpsDepositTerms(
            sourceAmount: review.sourceAmount,
            sourceSymbol: review.sourceAsset.symbol,
            creditedAmount: review.creditedAmount,
            creditedSymbol: PerpsDepositService.targetAsset.symbol,
            networkFee: review.networkFee,
            networkFeeSymbol: review.networkFeeSymbol,
            networkFeeUsd: Self.usd(of: review.networkFee, price: nativePrice),
            resumesPayment: review.resumesPayment,
            expiresAt: review.expiresAt,
            estimatedDurationSeconds: review.estimatedDurationSeconds,
            delegatedNetworks: review.delegatedChains.map(PerpsFundingNetwork.init)
        )
        return PerpsReviewedDeposit(terms: terms) { [self] passcode in
            try await service.pay(review: review, passcode: passcode) { fee in
                _ = try await self.checkNetworkFee(review, fee: fee)
            }
        }
    }

    private func checkNetworkFee(_ review: PerpsDepositReview, fee: String?) async throws -> Decimal? {
        // A payment being finished was checked when it was signed, and its own spending has
        // since left the balance.
        if !review.resumesPayment,
           let native = await loadAsset("\(review.sourceChain.rawValue)/mainnet/coin")
        {
            // The chain's own coin pays the fee, and the amount too when it is the source: a
            // payment the balance does not cover would be signed and then fail on chain.
            // Unpriced, the fee is still more than nothing.
            let spendsNative = native.asset.assetId.lowercased() == review.sourceAsset.assetId.lowercased()
            let amount = spendsNative ? Self.decimal(review.sourceAmount) ?? 0 : 0
            let balance = Self.decimal(units: native.balance, decimals: native.asset.decimals)
            let required = fee.flatMap(Self.decimal).map { amount + $0 }
            let covered = if let required {
                balance >= required
            } else {
                !spendsNative || balance > amount
            }
            guard covered else {
                Log.w("🪵 Perps deposit: fee not covered balance=\(balance) amount=\(amount) fee=\(fee ?? "nil")")
                throw PerpsLiveDepositError.insufficientNetworkFee(symbol: review.networkFeeSymbol, required: required.map { "\($0)" })
            }
            return Self.usdPrice(of: native)
        }
        return nil
    }

    func message(for error: Error) -> PerpsDepositMessage {
        if case let PerpsLiveDepositError.insufficientNetworkFee(symbol, required) = error {
            return .insufficientNetworkFee(symbol: symbol, required: required)
        }
        let message = PerpsDepositService.message(for: error)
        // The form refuses an amount over the balance before quoting, so a chain's own coin
        // refused here is short of its fee, not of the amount.
        if message == .insufficientBalance, selectableSource(source.assetId)?.asset.isNative == true {
            return .insufficientNetworkFee(symbol: source.symbol)
        }
        return message
    }

    /// Gas is priced again when the call is signed, and the base fee can rise 12.5% a block.
    private static let gasFeeHeadroom: Decimal = 1.25

    private static func depositSource(_ asset: PerpsFundingAsset, on network: PerpsFundingNetwork) -> PerpsDepositSource {
        PerpsDepositSource(assetId: asset.assetId, symbol: asset.symbol, decimals: asset.decimals, network: network)
    }

    private func loadAsset(_ assetId: String) async -> MultichainAsset? {
        if let task = assetLoads[assetId] { return await task.value }
        let task = Task { [assetBalanceProvider, wallet] in
            await assetBalanceProvider.loadAsset(for: assetId, wallet: wallet, includingHidden: true)
        }
        assetLoads[assetId] = task
        defer { assetLoads[assetId] = nil }
        return await task.value
    }

    /// The wallet's listing names only the assets it holds or held: one it never held is read with
    /// `show_all`, so the screen still has its icon and price, and a zero balance.
    private func loadListedAsset(_ assetId: String) async -> MultichainAsset? {
        if let asset = await loadAsset(assetId) { return asset }
        guard let state = wallet.multichainWalletState, !Task.isCancelled else { return nil }
        do {
            return try await multichainService.getWalletAssets(
                state: state,
                currencies: ["usd"],
                assetIds: [assetId],
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: false,
                showHidden: true,
                showAll: true,
                hideDust: false,
                limit: nil,
                cursor: nil
            ).assets.first { $0.asset.assetId.lowercased() == assetId.lowercased() }
        } catch {
            Log.perps.failure("Deposit asset show_all load failed asset=\(assetId)", error: error)
            return nil
        }
    }

    static func nativeLimit(
        balance: Decimal,
        decimals: Int,
        fee: (String) async -> Decimal?
    ) async -> String? {
        // A full-balance Bitcoin PSBT may be impossible to quote before reserving its fee.
        var probe: (amount: Decimal, fee: Decimal)?
        for amount in [balance, balance * 9 / 10, balance / 2] {
            if let quoted = await fee(amount.description) {
                probe = (amount, quoted)
                break
            }
        }
        guard let probe else { return nil }
        let payable = probe.amount + probe.fee * gasFeeHeadroom <= balance ? roundedDown(probe.amount, decimals) : 0
        var candidate = max(balance - probe.fee * gasFeeHeadroom, 0)
        for _ in 0 ..< 3 {
            let rounded = roundedDown(candidate, decimals)
            guard rounded > 0 else { return "0" }
            guard let actual = await fee(rounded.description) else {
                // A Bitcoin balance can count outputs this payment cannot spend, so a quote refuses
                // an amount the balance covers: Max settles on the largest one it still quotes.
                return await largestPayable(above: payable, below: rounded, balance: balance, decimals: decimals, fee: fee)
            }
            if rounded + actual <= balance { return rounded.description }
            candidate = max(balance - actual * gasFeeHeadroom, 0)
        }
        return nil
    }

    private static func largestPayable(
        above payable: Decimal,
        below refused: Decimal,
        balance: Decimal,
        decimals: Int,
        fee: (String) async -> Decimal?
    ) async -> String? {
        var low = payable
        var high = refused
        for _ in 0 ..< 3 {
            let middle = roundedDown((low + high) / 2, decimals)
            guard middle > low else { break }
            if let actual = await fee(middle.description), middle + actual * gasFeeHeadroom <= balance {
                low = middle
            } else {
                high = middle
            }
        }
        return low > 0 ? low.description : nil
    }

    private static func roundedDown(_ value: Decimal, _ decimals: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, decimals, .down)
        return result
    }

    private static func usdPrice(of asset: MultichainAsset) -> Decimal? {
        let prices = asset.price.prices
        guard let price = prices["USD"] ?? prices["usd"], price > 0 else { return nil }
        return Decimal(price)
    }

    private static func usd(of amount: String?, price: Decimal?) -> Decimal? {
        guard let amount, let price, let value = decimal(amount) else { return nil }
        return value * price
    }

    private static func decimal(_ declaredAmount: String) -> Decimal? {
        Decimal(string: declaredAmount, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func decimal(units: BigUInt, decimals: Int) -> Decimal {
        guard let value = Decimal(string: units.description) else { return 0 }
        return value / pow(Decimal(10), decimals)
    }
}

private enum PerpsLiveDepositError: Error {
    case sourceAddressUnavailable
    case insufficientNetworkFee(symbol: String, required: String?)
}

extension PerpsFundingNetwork {
    init(_ chain: MultichainChain) {
        switch chain {
        case .ton: self = .ton
        case .eth: self = .ethereum
        case .base: self = .base
        case .arb: self = .arbitrum
        case .bsc: self = .bsc
        case .tron: self = .tron
        case .btc: self = .bitcoin
        case .sol: self = .sol
        case .robinhood: self = .robinhood
        case .avax: self = .avax
        case .polygon: self = .polygon
        }
    }

    init?(assetId: String) {
        guard let chain = MultichainChain(assetId: assetId) else { return nil }
        self.init(chain)
    }
}
