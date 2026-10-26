import Foundation
import PerpsModels
import TKLocalize
import TKLogging

struct PerpsFundingAmountConfig<Reviewed> {
    let title: String
    /// Read as the screen renders: finishing a pending payment re-selects the asset it was paid with.
    let asset: () -> PerpsDepositSource
    var displayAsset: ((PerpsFundingBalance?) -> PerpsFundingAssetRow)? = nil
    let initialUnit: PerpsFundingAmountInput.Unit
    /// Overrides the wallet's price of the asset: the Perps balance counts USDC as dollars.
    let fixedUsdPrice: Decimal?
    let loadBalance: () async -> PerpsFundingBalance?
    /// The most that can be sent, in whole tokens. `nil` spends up to the wallet's balance.
    let loadLimit: (() async -> String?)?
    /// A fee reserve estimates Max; the entered amount's own quote checks its actual fee.
    var limitIsMaxOnly = false
    var requiresLimit = false
    /// Review stays off below it, so the floor is named before a quote is asked for.
    var loadMinimum: (() async -> PerpsFundingMinimum?)? = nil
    /// The asset to start from instead of `asset`, looked up as the screen first loads and
    /// switched to with `selectAsset` unless the user has already entered or picked something.
    var loadPreferredAsset: (() async -> PerpsDepositSourceOption?)? = nil
    var selectAsset: ((PerpsDepositSourceOption) -> Void)? = nil
    let review: (_ amount: String) async throws -> Reviewed
    /// `nil` where the user already knows why, as after a cancelled passcode.
    let errorText: (Error) -> String?
}

struct PerpsFundingMinimum {
    /// In whole tokens of the asset.
    let amount: Decimal
    let text: String
}

@MainActor
final class PerpsFundingAmountViewModel<Reviewed>: PerpsFundingAmountViewModeling {
    @Published private(set) var input: PerpsFundingAmountInput
    @Published private(set) var balance: PerpsFundingBalance?
    @Published private(set) var limit: Decimal?
    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var errorText: String?
    @Published private(set) var isReviewInFlight = false
    /// Max was tapped while the limit was still being priced: it lands once the limit does.
    @Published private(set) var isMaxPending = false
    @Published private var isLimitLoading = false
    @Published private var pendingReview: Reviewed?
    @Published private var minimum: PerpsFundingMinimum?

    var onReviewed: ((Reviewed) -> Void)?
    var onClose: (() -> Void)?
    var onChooseAsset: ((PerpsFundingAssetRow) -> Void)?
    var onAddFunds: (() -> Void)?

    private let config: PerpsFundingAmountConfig<Reviewed>
    private let format: PerpsFormatting
    private let loadPendingReview: (() async throws -> Reviewed?)?
    private let pendingNotice: String?
    private var loadTask: Task<Void, Never>?
    private var reviewTask: Task<Void, Never>?
    private var isAssetChosen = false

    init(
        config: PerpsFundingAmountConfig<Reviewed>,
        format: PerpsFormatting,
        loadPendingReview: (() async throws -> Reviewed?)? = nil,
        pendingNotice: String? = nil
    ) {
        self.config = config
        self.format = format
        self.loadPendingReview = loadPendingReview
        self.pendingNotice = pendingNotice
        input = PerpsFundingAmountInput(
            tokenDecimals: config.asset().decimals,
            unit: config.initialUnit,
            usdPrice: config.fixedUsdPrice
        )
    }

    deinit {
        loadTask?.cancel()
        reviewTask?.cancel()
    }

    private var symbol: String {
        config.asset().symbol
    }

    var titleText: String {
        config.title
    }

    var amountText: String {
        input.text
    }

    var amountPrefix: String {
        input.unit == .usd ? "$" : ""
    }

    var amountSuffix: String? {
        input.unit == .token ? symbol : nil
    }

    var counterpartText: String? {
        guard input.canToggleUnit else { return nil }
        switch input.unit {
        case .token:
            return format.usd(Self.double(input.usdAmount ?? 0))
        case .usd:
            return tokenText(input.tokenAmount ?? 0)
        }
    }

    var canToggleUnit: Bool {
        input.canToggleUnit
    }

    var availableText: String {
        guard let availableAmount else { return PerpsFundingText.missing }
        return input.unit == .usd && input.canToggleUnit
            ? format.usd(Self.double(availableAmount * (input.usdPrice ?? 0)))
            : tokenText(availableAmount)
    }

    var isMaxEnabled: Bool {
        guard !isReviewInFlight else { return false }
        // A chain's own coin prices its fee before Max is known; the tap waits for it.
        if isLimitLoading { return (balanceAmount ?? 0) > 0 }
        return (limit ?? 0) > 0
    }

    var canAddFunds: Bool {
        onAddFunds != nil
    }

    var asset: PerpsFundingAssetRow {
        if let displayAsset = config.displayAsset { return displayAsset(balance) }
        let source = config.asset()
        return PerpsFundingAssetRow(
            assetId: source.assetId,
            symbol: source.symbol,
            network: source.network,
            iconURL: balance?.iconURL,
            balanceText: balance.flatMap { format.fundingBalance($0, symbol: source.symbol) }
        )
    }

    var warningText: String? {
        if let errorText { return errorText }
        if pendingReview != nil { return pendingNotice }
        if exceedsLimit { return TKLocales.Perps.Funding.insufficientBalance }
        return isBelowMinimum ? minimum?.text : nil
    }

    var isReviewEnabled: Bool {
        if pendingReview != nil { return !isReviewInFlight }
        if config.requiresLimit, limit == nil { return false }
        guard !isReviewInFlight, let amount = input.tokenAmount, amount > 0 else { return false }
        return !exceedsLimit && !isBelowMinimum
    }

    private var exceedsLimit: Bool {
        guard let availableAmount, let amount = input.tokenAmount else { return false }
        return amount > availableAmount
    }

    private var isBelowMinimum: Bool {
        guard let minimum, let amount = input.tokenAmount, amount > 0 else { return false }
        return amount < minimum.amount
    }

    private var availableAmount: Decimal? {
        config.limitIsMaxOnly ? balanceAmount : limit
    }

    private var balanceAmount: Decimal? {
        balance.flatMap { PerpsFundingAmountInput.decimal($0.amount) }
    }

    /// The config's asset was switched in place. `balance` is what the picker already knows of
    /// the new one: the screen shows it at once instead of a blank row until its own load lands.
    func assetDidChange(balance: PerpsFundingBalance?) {
        isAssetChosen = true
        loadTask?.cancel()
        loadTask = nil
        reviewTask?.cancel()
        reviewTask = nil
        isReviewInFlight = false
        pendingReview = nil
        errorText = nil
        isMaxPending = false
        minimum = nil
        self.balance = balance
        limit = config.loadLimit == nil ? balanceAmount : nil
        input = PerpsFundingAmountInput(
            tokenDecimals: config.asset().decimals,
            unit: config.initialUnit,
            usdPrice: config.fixedUsdPrice ?? balance?.usdPrice
        )
        onAppear()
    }

    func onAppear() {
        guard loadTask == nil else { return }
        isLimitLoading = config.loadLimit != nil
        loadTask = Task { [weak self, config, loadPendingReview] in
            if let loadPendingReview {
                do {
                    let pending = try await loadPendingReview()
                    guard !Task.isCancelled, let self else { return }
                    if pending != nil {
                        // Finishing a payment re-selects the asset it was paid with.
                        balance = nil
                        input = PerpsFundingAmountInput(
                            tokenDecimals: config.asset().decimals,
                            unit: input.unit,
                            usdPrice: config.fixedUsdPrice
                        )
                    }
                    pendingReview = pending
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.errorText = config.errorText(error)
                }
            }
            let loadPreferredAsset = self?.isAssetChosen == false && self?.pendingReview == nil
                ? config.loadPreferredAsset
                : nil
            async let preferredAsset = loadPreferredAsset?()
            async let balance = config.loadBalance()
            async let limit = config.loadLimit?()
            async let minimum = config.loadMinimum?()
            let (loadedBalance, loadedLimit) = await(balance, limit)
            guard !Task.isCancelled, let self else { return }
            self.balance = loadedBalance
            if config.fixedUsdPrice == nil {
                input.setUsdPrice(loadedBalance?.usdPrice)
            }
            let limitText = config.loadLimit == nil ? loadedBalance?.amount : loadedLimit
            self.limit = limitText.flatMap(PerpsFundingAmountInput.decimal)
            isLimitLoading = false
            if isMaxPending {
                isMaxPending = false
                if isMaxEnabled { setMax() }
            }
            let loadedMinimum = await minimum
            guard !Task.isCancelled else { return }
            self.minimum = loadedMinimum
            if loadPreferredAsset != nil {
                let preferred = await preferredAsset
                guard !Task.isCancelled else { return }
                if let preferred { startsFrom(preferred) }
                isAssetChosen = true
            }
        }
    }

    /// Switches only where nothing on the screen belongs to the current asset yet.
    private func startsFrom(_ preferred: PerpsDepositSourceOption) {
        guard !isAssetChosen, let selectAsset = config.selectAsset,
              preferred.source.assetId.lowercased() != config.asset().assetId.lowercased(),
              input.text.isEmpty, !isMaxPending, !isReviewInFlight
        else { return }
        selectAsset(preferred)
        assetDidChange(balance: preferred.balance)
    }

    func requestFocusOnAppear() {
        amountFocusState = amountFocusState.activated(requestFocus: true)
    }

    func setAmount(_ text: String) {
        input.setText(text)
        errorText = nil
        isMaxPending = false
    }

    func toggleUnit() {
        input.toggleUnit()
    }

    func setMax() {
        guard let limit else {
            isMaxPending = isMaxEnabled
            return
        }
        input.setMax(limit)
        errorText = nil
    }

    func review() {
        guard isReviewEnabled else { return }
        if let pendingReview {
            onReviewed?(pendingReview)
            return
        }
        guard let amount = input.tokenAmount else { return }
        reviewTask?.cancel()
        isReviewInFlight = true
        errorText = nil
        let amountText = PerpsFundingAmountInput.text(amount)
        reviewTask = Task { [weak self, config] in
            do {
                let reviewed = try await config.review(amountText)
                guard !Task.isCancelled else { return }
                self?.isReviewInFlight = false
                self?.onReviewed?(reviewed)
            } catch {
                guard !Task.isCancelled else { return }
                Log.w("🪵 Perps funding: review failed", error: error)
                self?.isReviewInFlight = false
                self?.errorText = config.errorText(error)
            }
        }
    }

    func addFunds() {
        onAddFunds?()
    }

    func chooseAsset() {
        guard !isReviewInFlight else { return }
        // A pick of the asset already shown changes nothing, so the open picker must not be switched under.
        isAssetChosen = true
        onChooseAsset?(asset)
    }

    func close() {
        onDisappear()
        onClose?()
    }

    func onDisappear() {
        loadTask?.cancel()
        loadTask = nil
        reviewTask?.cancel()
        reviewTask = nil
        isReviewInFlight = false
        pendingReview = nil
        isMaxPending = false
        isLimitLoading = false
    }

    private func tokenText(_ amount: Decimal) -> String {
        format.tokenCompact(amount, symbol: symbol)
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

typealias PerpsDepositAmountViewModel = PerpsFundingAmountViewModel<PerpsReviewedDeposit>
typealias PerpsWithdrawAmountViewModel = PerpsFundingAmountViewModel<PerpsReviewedWithdraw>

extension PerpsFormatting {
    /// "0.0000356 BTC · $3.56"; dollars only where the asset has a price.
    func fundingBalance(_ balance: PerpsFundingBalance, symbol: String) -> String? {
        guard let amount = PerpsFundingAmountInput.decimal(balance.amount) else { return nil }
        let token = tokenCompact(amount, symbol: symbol)
        guard let price = balance.usdPrice else { return token }
        return "\(token) · \(usd(NSDecimalNumber(decimal: amount * price).doubleValue))"
    }
}

extension Array where Element == PerpsDepositSourceOption {
    /// The holding worth the most dollars; `nil` when nothing priced is held.
    var largestHolding: PerpsDepositSourceOption? {
        let valued = compactMap { option -> (option: PerpsDepositSourceOption, usd: Decimal)? in
            guard let balance = option.balance, let price = balance.usdPrice,
                  let amount = PerpsFundingAmountInput.decimal(balance.amount)
            else { return nil }
            return (option, amount * price)
        }
        return valued.filter { $0.usd > 0 }.max { $0.usd < $1.usd }?.option
    }
}

enum PerpsFundingText {
    /// A field the design asks for with no source behind it yet.
    static let missing = "—"
}
