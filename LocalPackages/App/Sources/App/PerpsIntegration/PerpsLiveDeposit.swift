import BigInt
import Foundation
import KeeperCore
import PerpsModels
import TKCoordinator
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class PerpsLiveDeposit: PerpsDepositing {
    let walletName: String

    private let service: PerpsDepositService
    private let accountService: PerpsAccountService
    private let address: String
    private let wallet: Wallet
    private let assetBalanceProvider: MultichainAssetBalanceProvider
    private let multichainService: any MultichainService
    private let assetDetailsService: any TradingAssetDetailsService
    private let amountFormatter: AmountFormatter
    private let feeRefill: PerpsFeeRefill
    private let batteryService: BatteryService
    private let isBatteryFeeEnabled: Bool
    /// Kept once known: the review re-quotes every few seconds.
    private var knownChargeCost: Decimal?
    private let sheetPresenter: @MainActor () async -> UIViewController?
    private(set) var source = PerpsLiveDeposit.depositSource(PerpsDepositService.targetAsset, on: .ethereum)
    private var selectableSources = [(asset: MultichainAsset, source: PerpsDepositSource)]()
    /// The last listing per set of accounts, kept while the app runs: offline, the picker reopens with it.
    private static var lastListedAssets = [String: [MultichainAsset]]()
    private var assetLoads = [String: Task<MultichainAsset?, Never>]()
    /// Kept across requotes, as a swap keeps it, until another is picked.
    private var pickedFeeMethod: MultichainSwapFeeMethod?
    /// Held while the picker is up: it reports a pick through its coordinator.
    private var feePickerCoordinator: NetworkFeePickerCoordinator?
    private var feeRefillCoordinator: Coordinator?

    init?(
        walletScope: PerpsWalletScope,
        assetBalanceProvider: MultichainAssetBalanceProvider,
        multichainService: any MultichainService,
        assetDetailsService: any TradingAssetDetailsService,
        amountFormatter: AmountFormatter,
        feeRefill: PerpsFeeRefill,
        batteryService: BatteryService,
        isBatteryFeeEnabled: Bool,
        sheetPresenter: @escaping @MainActor () async -> UIViewController?
    ) {
        guard let service = walletScope.depositService,
              let address = walletScope.wallet.multichainAddress(for: .eth)
        else { return nil }
        self.service = service
        accountService = walletScope.accountService
        self.address = address
        self.assetBalanceProvider = assetBalanceProvider
        self.multichainService = multichainService
        self.assetDetailsService = assetDetailsService
        self.amountFormatter = amountFormatter
        self.feeRefill = feeRefill
        self.batteryService = batteryService
        self.isBatteryFeeEnabled = isBatteryFeeEnabled
        self.sheetPresenter = sheetPresenter
        let wallet = walletScope.wallet
        self.wallet = wallet
        walletName = wallet.emojiLabel
    }

    var holdsTradingKey: Bool {
        accountService.holdsKeptTradingKey(wallet: wallet)
    }

    func keepTradingKey(passcode: String) async -> Bool {
        await accountService.keepTradingKey(wallet: wallet, passcode: passcode)
    }

    private var operationLogFields: [String: String] {
        ["flow": "deposit", "wallet_id": wallet.multichainWalletState?.walletId ?? wallet.id,
         "asset_id": source.assetId, "chain": String(source.assetId.split(separator: "/").first ?? "unknown")]
    }

    func loadBalance() async -> PerpsFundingBalance? {
        return await PerpsOperationLog.step("balance", source: "backend", fields: operationLogFields) {
            let selected = source
            guard let asset = await loadListedAsset(selected), source == selected else {
                PerpsOperationLog.event("balance", outcome: "unavailable", source: "unknown", fields: ["reason": source == selected ? "asset_unavailable" : "asset_changed"])
                return nil
            }
            return PerpsFundingBalance(
                amount: Self.decimal(units: asset.balance, decimals: asset.asset.decimals).description,
                usdPrice: Self.usdPrice(of: asset),
                iconURL: URL(string: asset.asset.image)
            )
        }
    }

    func loadMinimum() async throws -> PerpsDepositMinimum? {
        return try await PerpsOperationLog.step("minimum", source: "backend", fields: operationLogFields) {
            let selected = source
            guard let chain = PerpsDepositService.fundingChain(assetId: selected.assetId),
                  let sender = wallet.multichainAddress(for: chain),
                  let price = await loadAsset(selected.assetId).flatMap({ Self.usdPrice(of: $0) })
            else { return nil }
            let found: (usd: String, units: BigUInt)?
            do {
                found = try await service.minimum(
                    sourceAsset: PerpsFundingAsset(assetId: selected.assetId, symbol: selected.symbol, decimals: selected.decimals),
                    usdPrice: price,
                    senderAddress: sender,
                    beneficiary: address
                )
            } catch {
                guard source == selected else { return nil }
                throw error
            }
            guard let minimum = found, source == selected else { return nil }
            return PerpsDepositMinimum(usd: minimum.usd, amount: Self.decimal(units: minimum.units, decimals: selected.decimals))
        }
    }

    func loadLimit() async -> String? {
        return await PerpsOperationLog.step("max_amount", source: "backend", fields: operationLogFields) {
            let selected = source
            guard let asset = await loadAsset(selected.assetId), source == selected else { return nil }
            let balance = Self.decimal(units: asset.balance, decimals: asset.asset.decimals)
            guard balance > 0, asset.isNative else { return balance.description }
            let fullBalance: Result<PerpsDepositReview, Error>
            do {
                // Quoted as Confirm quotes it: from Ethereum a payment that registers the key can only be
                // paid with the coin, so it keeps its fee.
                fullBalance = try await .success(quoteReview(amount: balance.description, previewing: false))
            } catch {
                PerpsOperationLog.event("max_amount", outcome: "unavailable", error: error)
                fullBalance = .failure(error)
            }
            guard source == selected else { return nil }
            // Battery charges or a token pay the fee, so the coin need not keep it: Max is the whole
            // balance, as a swap's is.
            if case let .success(review) = fullBalance, await relayedFeeCovers(review) {
                return source == selected ? balance.description : nil
            }
            var belowMinimum: String?
            let estimated = await Self.nativeLimit(balance: balance, decimals: asset.asset.decimals) { [weak self] amount in
                guard let self, self.source == selected else { return nil }
                do {
                    let review = try await amount == balance.description
                        ? fullBalance.get()
                        : self.quoteReview(amount: amount, registeringKey: false, previewing: false)
                    let fee = review.networkFee.flatMap(Self.decimal)
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
    }

    func availableSources() async -> PerpsDepositSources {
        return await PerpsOperationLog.step("assets", source: "backend", fields: operationLogFields) {
            guard let state = wallet.multichainWalletState else {
                return PerpsDepositSources(options: [PerpsDepositSourceOption(source: source, balance: await loadBalance())], isFresh: true)
            }
            var assets: [MultichainAsset]
            var isFresh = true
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
                Self.lastListedAssets[state.accountsIdentifier] = assets
            } catch {
                PerpsOperationLog.event("assets", outcome: "failed", source: "backend", error: error, fields: ["cached_count": String(selectableSources.count)])
                if !selectableSources.isEmpty || Task.isCancelled { return PerpsDepositSources(options: sourceOptions, isFresh: false) }
                assets = cachedDepositAssets(state: state)
                isFresh = false
            }
            guard !Task.isCancelled else { return PerpsDepositSources(options: sourceOptions, isFresh: false) }
            let returnedIds = assets.map { $0.asset.assetId }
            if !assets.contains(where: { $0.asset.assetId.lowercased() == PerpsDepositService.targetAsset.assetId }),
               let direct = await loadListedAsset(Self.depositSource(PerpsDepositService.targetAsset, on: .ethereum))
            {
                assets.insert(direct, at: 0)
            }
            guard !Task.isCancelled else { return PerpsDepositSources(options: sourceOptions, isFresh: false) }
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
            let options = sourceOptions
            PerpsOperationLog.event("assets", outcome: "loaded", source: "backend", fields: ["returned_asset_ids": returnedIds.joined(separator: ","), "unsupported_asset_ids": unsupportedIds.joined(separator: ","), "picker_asset_ids": options.map { $0.source.assetId }.joined(separator: ",")])
            return PerpsDepositSources(options: options, isFresh: isFresh)
        }
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
        }.sortedByHoldingValue
    }

    func selectSource(assetId: String) {
        guard let selected = selectableSource(assetId) else { return }
        source = selected.source
    }

    private func selectableSource(_ assetId: String) -> (asset: MultichainAsset, source: PerpsDepositSource)? {
        selectableSources.first { $0.source.assetId.lowercased() == assetId.lowercased() }
    }

    func review(amount: String) async throws -> PerpsReviewedDeposit {
        return try await PerpsOperationLog.step("review", source: "client", fields: operationLogFields.merging(["amount": amount]) { _, new in new }) {
            try await makeReviewed(quoteReview(amount: amount))
        }
    }

    private func quoteReview(amount: String, registeringKey: Bool = true, previewing: Bool = true) async throws -> PerpsDepositReview {
        guard let chain = PerpsDepositService.fundingChain(assetId: source.assetId),
              let sender = wallet.multichainAddress(for: chain)
        else {
            PerpsOperationLog.event("sender_address", outcome: "unavailable", source: "wallet", fields: operationLogFields)
            throw PerpsLiveDepositError.sourceAddressUnavailable
        }
        return try await service.review(
            sourceAsset: PerpsFundingAsset(assetId: source.assetId, symbol: source.symbol, decimals: source.decimals),
            amount: amount,
            senderAddress: sender,
            beneficiary: address,
            registeringKey: registeringKey,
            previewing: previewing
        )
    }

    func pendingReview() async throws -> PerpsReviewedDeposit? {
        return try await PerpsOperationLog.step("pending_review", source: "client", fields: operationLogFields) {
            guard let review = try await service.pendingReview() else {
                return nil
            }
            let network = PerpsFundingNetwork(review.sourceChain)
            source = Self.depositSource(review.sourceAsset, on: network)
            return try await makeReviewed(review)
        }
    }

    private func makeReviewed(_ review: PerpsDepositReview) async throws -> PerpsReviewedDeposit {
        let native = await nativeFee(review, fee: review.networkFee)
        let choice = await feeChoice(review, native: native)
        // With another method on offer the confirmation names the shortage and offers each
        // method's top-up, as a swap does.
        if choice == nil, let shortage = native.shortage {
            throw shortage
        }
        let selected = choice.flatMap { MultichainSwapFeeSelection.resolve(options: $0.options, picked: pickedFeeMethod) }
        PerpsOperationLog.event("review", outcome: "ready", fields: ["amount": review.sourceAmount, "receive_amount": review.creditedAmount, "network_fee": review.networkFee ?? "unknown", "network_fee_symbol": review.networkFeeSymbol, "resuming": String(review.resumesPayment), "fee_method": selected?.method.id ?? "native"])

        return makeReviewed(review, nativePrice: native.price, choice: choice, selected: selected, logContext: PerpsOperationLog.context)
    }

    private func makeReviewed(
        _ review: PerpsDepositReview,
        nativePrice: Decimal?,
        choice: FeeChoice?,
        selected: MultichainSwapFeeOption?,
        logContext: [String: String]
    ) -> PerpsReviewedDeposit {
        let relayed = selected.flatMap { $0.method.isRelayed ? $0 : nil }
        let relayedFee = relayed.flatMap { choice?.fee(of: $0) }
        let terms = PerpsDepositTerms(
            sourceAmount: review.sourceAmount,
            sourceSymbol: review.sourceAsset.symbol,
            creditedAmount: review.creditedAmount,
            creditedSymbol: PerpsDepositService.targetAsset.symbol,
            // An unpriced battery shows no amount, as the swap's fee row shows it.
            networkFee: relayed == nil ? review.networkFee : relayedFee?.amount,
            networkFeeSymbol: relayedFee?.symbol ?? review.networkFeeSymbol,
            networkFeeUsd: relayed == nil ? Self.usd(of: review.networkFee, price: nativePrice) : relayedFee?.usd,
            feeMethodTitle: selected?.extraType.feeRowMethodTitle,
            paysFeeInCharges: relayed?.method == .battery,
            networkFeeReserve: relayedFee?.reserve,
            feeShortageSymbol: selected?.isInsufficient == true ? review.networkFeeSymbol : nil,
            providerFees: review.providerFees,
            resumesPayment: review.resumesPayment,
            expiresAt: review.expiresAt,
            estimatedDurationSeconds: review.estimatedDurationSeconds,
            delegatedNetworks: review.delegatedChains.map(PerpsFundingNetwork.init),
            accountUninitialized: review.accountUninitialized,
            createsAccount: review.createsAccount,
            sentAmount: review.sentAmount,
            provider: review.provider
        )
        // A method that cannot pay still opens the picker: that is the only way to reach its top-up.
        let pickFee: PerpsDepositFeePicking? = if let choice, let selected, choice.options.count > 1 || selected.isInsufficient {
            { [weak self] picked in
                self?.presentFeePicker(options: choice.options, selected: selected) { [weak self] option in
                    guard let self else { return }
                    pickedFeeMethod = option.method
                    picked(makeReviewed(review, nativePrice: nativePrice, choice: choice, selected: option, logContext: logContext))
                } onRefilled: {
                    picked(nil)
                }
            }
        } else {
            nil
        }
        return PerpsReviewedDeposit(terms: terms, review: review.review(relayedFee: relayed), pickFee: pickFee) { [self, walletAsset = choice?.walletAsset] passcode, consent in
            try await PerpsOperationLog.$context.withValue(logContext) {
                try await service.pay(review: review, passcode: passcode, consent: consent, relayedFee: relayed, walletAsset: walletAsset) { fee in
                    _ = try await self.checkNetworkFee(review, fee: fee)
                }
            }
        }
    }

    /// What pays a deposit's source fee when it need not be the chain's own coin, priced in dollars.
    private struct FeeChoice {
        struct Fee {
            let amount: String
            let symbol: String
            let usd: Decimal?
            var reserve: String? = nil
        }

        /// Relayed first, the chain's own coin last, as a swap offers them.
        let options: [MultichainSwapFeeOption]
        let walletAsset: MultichainAsset
        let prices: [String: Decimal]
        let chargeUsd: Decimal?

        func fee(of option: MultichainSwapFeeOption) -> Fee? {
            switch option.cost {
            case .batteryCharges:
                guard let (cost, reserve) = option.batteryCharges else { return nil }
                return Fee(
                    amount: "\(cost)",
                    symbol: TKLocales.Battery.Refill.chargesCount(count: cost),
                    usd: chargeUsd.map { Decimal(cost) * $0 },
                    reserve: reserve.map { "\($0) \(TKLocales.Battery.Refill.chargesCount(count: $0))" }
                )
            case let .token(asset, amount, _):
                return fee(units: amount, of: asset)
            case let .gram(amountNano, _):
                return fee(units: amountNano, of: .gram)
            case .native, .batteryUnpriced:
                return nil
            }
        }

        private func fee(units: BigUInt, of asset: MultichainAssetDetails) -> Fee {
            let amount = PerpsLiveDeposit.decimal(units: units, decimals: asset.decimals)
            return Fee(amount: amount.description, symbol: asset.symbol, usd: prices[asset.assetId.lowercased()].map { amount * $0 })
        }
    }

    /// Whether the review's fee goes to battery charges or a token rather than the chain's own coin.
    /// A coin the user picked to pay keeps its fee reserved.
    private func relayedFeeCovers(_ review: PerpsDepositReview) async -> Bool {
        guard pickedFeeMethod != .native,
              let choice = await feeChoice(review, native: nativeFee(review, fee: review.networkFee)),
              let selected = MultichainSwapFeeSelection.resolve(options: choice.options, picked: pickedFeeMethod)
        else { return false }
        return selected.method.isRelayed && !selected.isInsufficient
    }

    /// `nil` where only the chain's own coin can pay, or where its fee is unknown and so cannot be
    /// weighed against the others.
    private func feeChoice(_ review: PerpsDepositReview, native: NativeFee) async -> FeeChoice? {
        guard !review.resumesPayment,
              let feeUnits = review.networkFeeUnits,
              let nativeAsset = native.asset,
              let walletAsset = await loadAsset(review.sourceAsset.assetId)
        else { return nil }
        let relayed = await service.feeOptions(of: review, walletAsset: walletAsset)
            .filter { isBatteryFeeEnabled || $0.method != .battery }
        guard !relayed.isEmpty else { return nil }
        var prices = [String: Decimal]()
        for asset in [walletAsset, nativeAsset] {
            prices[asset.asset.assetId.lowercased()] = Self.usdPrice(of: asset)
        }
        for option in relayed {
            let assetId = switch option.cost {
            case let .token(asset, _, _): asset.assetId
            // The battery sells a charge for GRAM.
            case .gram, .batteryCharges: MultichainAssetDetails.gram.assetId
            case .native, .batteryUnpriced: nil as String?
            }
            guard let assetId, prices[assetId.lowercased()] == nil else { continue }
            prices[assetId.lowercased()] = await loadAsset(assetId).flatMap(Self.usdPrice)
        }
        let gramPrice = prices[MultichainAssetDetails.gram.assetId.lowercased()]
        let chargeUsd: Decimal? = if let gramPrice, relayed.contains(where: { $0.method == .battery }) {
            await chargeCost().map { $0 * gramPrice }
        } else {
            nil
        }
        let nativeOption = MultichainSwapFeeOption(cost: .native(
            [MultichainTransactionEmulationResult(fee: feeUnits, asset: nativeAsset.asset)],
            isInsufficient: native.shortage != nil
        ))
        return FeeChoice(options: relayed + [nativeOption], walletAsset: walletAsset, prices: prices, chargeUsd: chargeUsd)
    }

    /// The GRAM one battery charge costs, as the battery's config names it.
    private func chargeCost() async -> Decimal? {
        if let knownChargeCost { return knownChargeCost }
        guard let config = try? await batteryService.loadBatteryConfig(wallet: wallet),
              let cost = Self.decimal(config.charge_cost), cost > 0
        else { return nil }
        knownChargeCost = cost
        return cost
    }

    private func presentFeePicker(
        options: [MultichainSwapFeeOption],
        selected: MultichainSwapFeeOption,
        onPick: @escaping @MainActor (MultichainSwapFeeOption) -> Void,
        onRefilled: @escaping @MainActor () -> Void
    ) {
        Task { [weak self] in
            guard let self, let presenter = await sheetPresenter(),
                  let navigationController = presenter as? UINavigationController ?? presenter.navigationController
            else { return }
            let amountFormatter = amountFormatter
            let items = options.map { option in
                NetworkFeePickerItem(
                    id: option.method.id,
                    leading: option.extraType.networkFeePickerLeading,
                    text: .titled(
                        title: option.extraType.networkFeePickerTitle,
                        subtitle: option.feeValueText(amountFormatter: amountFormatter)
                    ),
                    isDisabled: option.isInsufficient,
                    actionTitle: option.isInsufficient ? TKLocales.FeeMethodPicker.deposit : nil,
                    isSelected: option.method == selected.method
                )
            }
            let coordinator = NetworkFeePickerCoordinator(router: ViewControllerRouter(rootViewController: navigationController))
            feePickerCoordinator = coordinator
            coordinator.start(presentation: NetworkFeePickerPresentation(
                configuration: NetworkFeePickerConfiguration(
                    title: TKLocales.FeeMethodPicker.title,
                    subtitle: TKLocales.FeeMethodPicker.subtitle
                ),
                dataSource: StaticNetworkFeePickerDataSource(items: items),
                didSelectItem: { [weak self] item, _ in
                    guard let self else { return }
                    feePickerCoordinator = nil
                    guard let option = options.first(where: { $0.method.id == item.id }) else { return }
                    guard option.isInsufficient else { return onPick(option) }
                    refill(option, from: presenter, onRefilled: onRefilled)
                }
            ))
        }
    }

    private func refill(_ option: MultichainSwapFeeOption, from presenter: UIViewController, onRefilled: @escaping @MainActor () -> Void) {
        let assetId = option.depositAsset?.assetId
        PerpsOperationLog.event("fee_refill", outcome: "started", fields: ["fee_method": option.method.id, "fee_asset": assetId ?? "battery"])
        feeRefillCoordinator = feeRefill.start(assetId: assetId, from: presenter) { [weak self] refilled in
            self?.feeRefillCoordinator = nil
            if refilled { onRefilled() }
        }
    }

    private struct NativeFee {
        /// The chain's own coin as the wallet holds it; `nil` for a payment being finished, or when unread.
        let asset: MultichainAsset?
        let price: Decimal?
        let shortage: PerpsLiveDepositError?
    }

    private func checkNetworkFee(_ review: PerpsDepositReview, fee: String?) async throws -> Decimal? {
        let native = await nativeFee(review, fee: fee)
        if let shortage = native.shortage { throw shortage }
        return native.price
    }

    private func nativeFee(_ review: PerpsDepositReview, fee: String?) async -> NativeFee {
        // A payment being finished was checked when it was signed, and its own spending has
        // since left the balance.
        guard !review.resumesPayment,
              let native = await loadAsset("\(review.sourceChain.rawValue)/mainnet/coin")
        else { return NativeFee(asset: nil, price: nil, shortage: nil) }
        // The chain's own coin pays the fee, and the amount too when it is the source, or the
        // coin a jetton payment carries: a payment the balance does not cover would be signed
        // and then fail on chain. Unpriced, the fee is still more than nothing.
        let spendsNative = native.asset.assetId.lowercased() == review.sourceAsset.assetId.lowercased()
        let amount = spendsNative
            ? Self.decimal(review.sourceAmount) ?? 0
            : review.carriedNativeAmount.flatMap(Self.decimal) ?? 0
        let balance = Self.decimal(units: native.balance, decimals: native.asset.decimals)
        let required = fee.flatMap(Self.decimal).map { amount + $0 }
        let covered = if let required {
            balance >= required
        } else {
            !spendsNative && amount == 0 || balance > amount
        }
        guard covered else {
            PerpsOperationLog.event("network_fee", outcome: "rejected", source: "wallet", fields: ["balance": balance.description, "amount": amount.description, "fee": fee ?? "unknown"])
            return NativeFee(
                asset: native,
                price: Self.usdPrice(of: native),
                shortage: .insufficientNetworkFee(symbol: review.networkFeeSymbol, required: required.map { "\($0)" })
            )
        }
        return NativeFee(asset: native, price: Self.usdPrice(of: native), shortage: nil)
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
        if let task = assetLoads[assetId] { return await task.value ?? selectableSource(assetId)?.asset }
        let task = Task { [assetBalanceProvider, wallet] in
            await assetBalanceProvider.loadAsset(for: assetId, wallet: wallet, includingHidden: true)
        }
        assetLoads[assetId] = task
        defer { assetLoads[assetId] = nil }
        return await task.value ?? selectableSource(assetId)?.asset
    }

    private func cachedDepositAssets(state: MultichainWalletState) -> [MultichainAsset] {
        let assets = (Self.lastListedAssets[state.accountsIdentifier] ?? [])
            .map { assetBalanceProvider.cachedAsset(for: $0.asset.assetId, multichainState: state) ?? $0 }
        PerpsOperationLog.event("assets", outcome: "cached", source: "memory", fields: ["cached_asset_ids": assets.map(\.asset.assetId).joined(separator: ",")])
        return assets
    }

    private func loadListedAsset(_ source: PerpsDepositSource) async -> MultichainAsset? {
        let assetId = source.assetId
        if let asset = await loadAsset(assetId) { return asset }
        guard let state = wallet.multichainWalletState, !Task.isCancelled else { return nil }
        do {
            return try await Self.loadListedAsset(source, loadAssets: {
                try await self.multichainService.getWalletAssets(
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
                ).assets
            }, loadDetails: {
                do {
                    let details = try await self.assetDetailsService.loadAssetDetails(id: assetId)
                    return MultichainAssetDetails(assetInfo: details.assetInfo)
                } catch {
                    PerpsOperationLog.event("asset_metadata", outcome: "failed", source: "backend", error: error, fields: ["asset_id": assetId])
                    return nil
                }
            })
        } catch {
            PerpsOperationLog.event("asset_lookup", outcome: "failed", source: "backend", error: error, fields: ["asset_id": assetId])
            return nil
        }
    }

    static func loadListedAsset(
        _ source: PerpsDepositSource,
        loadAssets: () async throws -> [MultichainAsset],
        loadDetails: () async -> MultichainAssetDetails?
    ) async throws -> MultichainAsset {
        let assets = try await loadAssets()
        try Task.checkCancellation()
        if let asset = assets.first(where: { $0.asset.assetId.lowercased() == source.assetId.lowercased() }) {
            return asset
        }
        // Even show_all can omit a token the wallet never held. Only a successful listing
        // establishes zero; its metadata can be read independently of the wallet's holdings.
        let details = await loadDetails()
        try Task.checkCancellation()
        return MultichainAsset(
            asset: details ?? MultichainAssetDetails(
                assetId: source.assetId,
                name: source.symbol,
                symbol: source.symbol,
                decimals: source.decimals,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: .zero
        )
    }

    static func nativeLimit(
        balance: Decimal,
        decimals: Int,
        fee: (String) async -> Decimal?
    ) async -> String? {
        // A full-balance Bitcoin PSBT may be impossible to quote before reserving its fee.
        var probe: (amount: Decimal, fee: Decimal)?
        var attempted = Set<Decimal>()
        for proposed in [balance, balance * 9 / 10, balance / 2] {
            let amount = roundedDown(proposed, decimals)
            guard amount > 0, attempted.insert(amount).inserted else { continue }
            if let quoted = await fee(amount.description) {
                probe = (amount, quoted)
                break
            }
        }
        guard let probe else { return nil }
        let payable = probe.amount + probe.fee * gasFeeHeadroom <= balance ? probe.amount : 0
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

    static func usdPrice(of asset: MultichainAsset) -> Decimal? {
        if asset.asset.symbol == PerpsDepositService.targetAsset.symbol { return 1 }
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

    fileprivate nonisolated static func decimal(units: BigUInt, decimals: Int) -> Decimal {
        NSDecimalNumber.fromBigUInt(value: units, decimals: decimals).decimalValue
    }
}

private enum PerpsLiveDepositError: Error, PerpsOperationLoggableError {
    var operationLogSource: String {
        "wallet"
    }

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
