import Foundation
import PerpsModels
import TKLocalize
import TKLogging

struct PerpsFundingAmountConfig<Reviewed> {
    var flow = "unknown"
    let title: String
    /// Read as the screen renders: finishing a pending payment re-selects the asset it was paid with.
    let asset: () -> PerpsDepositSource
    var displayAsset: ((_ balance: PerpsFundingBalance?, _ destination: PerpsDepositSourceOption?) -> PerpsFundingAssetRow)? = nil
    /// What the amount pays out in, with its wallet balance and price: set where the amount itself is
    /// dollars of the Perps balance. Its token is then the other unit of the entry.
    var loadDestination: (() async -> PerpsDepositSourceOption?)? = nil
    let initialUnit: PerpsFundingAmountInput.Unit
    var allowsUnitSwitching = true
    /// `false` where the asset cell under the amount already shows the balance.
    var showsAvailable = true
    /// Overrides the wallet's price of the asset: the Perps balance counts USDC as dollars.
    let fixedUsdPrice: Decimal?
    var loadIcon: (() async -> URL?)? = nil
    let loadBalance: () async -> PerpsFundingBalance?
    /// The most that can be sent, in whole tokens. `nil` spends up to the wallet's balance.
    let loadLimit: (() async -> String?)?
    /// A fee reserve estimates Max; the entered amount's own quote checks its actual fee.
    var limitIsMaxOnly = false
    var requiresLimit = false
    /// Review stays off below it, so the floor is named before a quote is asked for.
    var loadMinimum: (() async throws -> PerpsFundingMinimum?)? = nil
    /// The asset to start from instead of `asset`, looked up as the screen first loads and
    /// switched to with `selectAsset` unless the user has already entered or picked something.
    var loadPreferredAsset: (() async -> PerpsDepositSourceOption?)? = nil
    var selectAsset: ((PerpsDepositSourceOption) -> Void)? = nil
    let review: (_ amount: String) async throws -> Reviewed
    /// `nil` where the user already knows why, as after a cancelled passcode.
    let errorText: (Error) -> String?
    /// An error no amount of the asset clears: the screen keeps it for the asset until it closes
    /// and shows it, with Review off, for every amount typed.
    var blocksAsset: ((Error) -> Bool)? = nil
    var isRegionRestricted: ((Error) -> Bool)? = nil
    /// Prices the amount under the field as it is typed, from the review the Review button asks for.
    var quote: ((Reviewed) -> PerpsFundingQuote?)? = nil
    var report: ((PerpsFundingAmountReport) -> Void)? = nil
}

enum PerpsFundingAmountReport {
    case reviewTapped(usdAmount: Decimal?)
    case refused(PerpsFundingRefusal)
    /// The minimum quote found the asset blocked before anything showed it; once per screen.
    case blockedInBackground
    case failed(Error)
    case unreadableQuote
}

enum PerpsFundingRefusal {
    case overBalance
    case belowMinimum
    case addressBlocked
}

struct PerpsFundingMinimum {
    /// In whole tokens of the asset.
    let amount: Decimal
    let text: String
}

struct PerpsFundingQuote {
    let receivedUsd: Decimal
    /// `nil` where a part is unknown or paid in charges: a partial sum would understate it.
    let feeUsd: Decimal?
    let expiresAt: Date?
    var accountUninitialized: Bool? = nil
}

extension PerpsFundingQuote {
    /// The fee is the confirmation's: gas on both chains and the provider's cut. The quote also
    /// keeps a slippage allowance, which is not a fee, so "You get" can be less than the amount minus the fee.
    init?(deposit terms: PerpsDepositTerms) {
        guard let received = PerpsFundingAmountInput.decimal(terms.creditedAmount) else { return nil }
        receivedUsd = received
        feeUsd = terms.paysFeeInCharges ? nil : terms.providerFees.flatMap { fees in
            terms.networkFeeUsd.map { $0 + fees.destinationGasUsd + fees.providerUsd }
        }
        expiresAt = terms.expiresAt
        accountUninitialized = terms.accountUninitialized
    }
}

enum PerpsFundingQuoteTiming {
    static let debounce: TimeInterval = 0.5
    /// A quote this close to its expiry is reviewed again, so the confirmation has time to pay it.
    static let expiryLead: TimeInterval = 45
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
    @Published private var isBalanceLoadInFlight = true
    @Published private var pendingReview: Reviewed?
    @Published private var minimum: PerpsFundingMinimum?
    @Published private(set) var destination: PerpsDepositSourceOption?
    @Published private var liveQuote: LiveQuote?

    private struct Quoted {
        let key: String
        let reviewed: Reviewed
        let quote: PerpsFundingQuote
        var isUsed = false
    }

    private enum LiveQuote {
        case quoted(Quoted)
        case failed(key: String, text: String)
    }

    var onReviewed: ((Reviewed) -> Void)?
    var onClose: (() -> Void)?
    var onChooseAsset: ((PerpsFundingAssetRow) -> Void)?
    var onAddFunds: (() -> Void)?
    var onChooseAnotherWallet: (() -> Void)?
    var onRegionRestricted: (() -> Void)?

    private let config: PerpsFundingAmountConfig<Reviewed>
    private let format: PerpsFormatting
    private let loadPendingReview: (() async throws -> Reviewed?)?
    private let pendingNotice: String?
    private let quoteDebounce: TimeInterval
    private let now: () -> Date
    private(set) var loadTask: Task<Void, Never>?
    private(set) var reviewTask: Task<Void, Never>?
    @Published private var isAssetChosen = false
    /// What each blocked asset's error says, by asset id.
    @Published private var blockedAssets: [String: String] = [:]
    private var reportedRefusalKey: String?
    private var reportedBackgroundBlock = false
    private var isOnScreen = false

    init(
        config: PerpsFundingAmountConfig<Reviewed>,
        format: PerpsFormatting,
        loadPendingReview: (() async throws -> Reviewed?)? = nil,
        pendingNotice: String? = nil,
        quoteDebounce: TimeInterval = PerpsFundingQuoteTiming.debounce,
        now: @escaping () -> Date = Date.init
    ) {
        self.config = config
        self.format = format
        self.loadPendingReview = loadPendingReview
        self.pendingNotice = pendingNotice
        self.quoteDebounce = quoteDebounce
        self.now = now
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
        destinationPrice != nil ? destination?.source.symbol ?? config.asset().symbol : config.asset().symbol
    }

    private var debitsInUsd: Bool {
        config.loadDestination != nil
    }

    private var destinationPrice: Decimal? {
        guard debitsInUsd, let price = destination?.balance?.usdPrice, price > 0 else { return nil }
        return price
    }

    /// What leaves the balance: the token entered, or its dollars where the balance is dollars.
    private var debitAmount: Decimal? {
        debitsInUsd ? input.usdAmount : input.tokenAmount
    }

    var titleText: String {
        config.title
    }

    var amountText: String {
        format.input(input.text)
    }

    var amountPrefix: String {
        !isAssetLoading && input.unit == .usd ? "$" : ""
    }

    var amountSuffix: String? {
        !isAssetLoading && input.unit == .token ? symbol : nil
    }

    var counterpartText: String? {
        if config.allowsUnitSwitching, !debitsInUsd, isBalanceLoading { return format.usd(0) }
        guard canToggleUnit else { return nil }
        switch input.unit {
        case .token:
            return usdText(input.usdAmount ?? 0)
        case .usd:
            return tokenText(input.tokenAmount ?? 0)
        }
    }

    var canToggleUnit: Bool {
        !isBalanceLoading && config.allowsUnitSwitching && input.canToggleUnit && (!debitsInUsd || destinationPrice != nil)
    }

    var isAssetLoading: Bool {
        !isAssetChosen && config.loadPreferredAsset != nil && pendingReview == nil && input.text.isEmpty
    }

    var isBalanceLoading: Bool {
        isAssetLoading || (isBalanceLoadInFlight && availableAmount == nil)
    }

    var availableText: String? {
        guard config.showsAvailable, !isAssetLoading, let availableAmount else { return nil }
        if let hidden = format.hiddenBalanceText { return hidden }
        if debitsInUsd {
            guard input.unit == .token, let price = destinationPrice else { return usdText(availableAmount) }
            return tokenText(PerpsFundingAmountInput.roundedDown(availableAmount / price, scale: input.tokenDecimals))
        }
        return input.unit == .usd && input.canToggleUnit
            ? usdText(availableAmount * (input.usdPrice ?? 0))
            : tokenText(availableAmount)
    }

    var isMaxEnabled: Bool {
        guard !isReviewInFlight, !isAssetLoading else { return false }
        // A chain's own coin prices its fee before Max is known; the tap waits for it.
        if isLimitLoading { return (balanceAmount ?? 0) > 0 }
        return (limit ?? 0) > 0
    }

    var canAddFunds: Bool {
        onAddFunds != nil
    }

    var asset: PerpsFundingAssetRow {
        if let displayAsset = config.displayAsset { return displayAsset(balance, destination) }
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
        if let blockText { return blockText }
        if exceedsLimit { return TKLocales.Perps.Funding.insufficientBalance }
        return isBelowMinimum ? minimum?.text : nil
    }

    var isReviewEnabled: Bool {
        if pendingReview != nil { return !isReviewInFlight }
        return !isReviewInFlight && canReviewAmount
    }

    /// The block refuses every amount from this wallet, so the button leads to another wallet instead of Review.
    var offersAnotherWallet: Bool {
        onChooseAnotherWallet != nil && refusal == .addressBlocked
    }

    private var canReviewAmount: Bool {
        if config.requiresLimit, limit == nil { return false }
        guard let amount = debitAmount, amount > 0 else { return false }
        return blockText == nil && !exceedsLimit && !isBelowMinimum
    }

    /// What the live quote prices: a change asks for a new one.
    var quoteKey: String? {
        guard config.quote != nil, pendingReview == nil, errorText == nil, canReviewAmount,
              let amount = debitAmount
        else { return nil }
        return "\(config.asset().assetId) \(PerpsFundingAmountInput.text(amount))"
    }

    var quoteLine: PerpsFundingQuoteLine? {
        guard let quoteKey else { return nil }
        switch liveQuote {
        case let .quoted(quoted) where quoted.key == quoteKey:
            return .quoted(received: usdText(quoted.quote.receivedUsd), fee: quoted.quote.feeUsd.map(feeText))
        case let .failed(key, text) where key == quoteKey:
            return .failed(text)
        default:
            return .fetching
        }
    }

    var showsActivationNote: Bool {
        guard case let .quoted(quoted) = liveQuote, quoted.key == quoteKey else { return false }
        return quoted.quote.accountUninitialized == true
    }

    var refusalKey: String? {
        guard config.report != nil, let refusal, let amount = debitAmount else { return nil }
        return "\(config.asset().assetId) \(PerpsFundingAmountInput.text(amount)) \(refusal)"
    }

    private var refusal: PerpsFundingRefusal? {
        guard errorText == nil, pendingReview == nil else { return nil }
        if blockText != nil { return .addressBlocked }
        if exceedsLimit { return .overBalance }
        return isBelowMinimum ? .belowMinimum : nil
    }

    private var reusableQuote: Quoted? {
        guard case let .quoted(quoted) = liveQuote, quoted.key == quoteKey, !quoted.isUsed else { return nil }
        if let expiresAt = quoted.quote.expiresAt,
           expiresAt.timeIntervalSince(now()) <= PerpsFundingQuoteTiming.expiryLead
        {
            return nil
        }
        return quoted
    }

    private var exceedsLimit: Bool {
        guard let availableAmount, let amount = debitAmount else { return false }
        return amount > availableAmount
    }

    private var blockText: String? {
        guard let amount = debitAmount, amount > 0 else { return nil }
        return blockedAssets[config.asset().assetId]
    }

    private var isBelowMinimum: Bool {
        guard let minimum, let amount = debitAmount, amount > 0 else { return false }
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
    func assetDidChange(balance: PerpsFundingBalance?, destination: PerpsDepositSourceOption? = nil) {
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
        liveQuote = nil
        self.balance = balance
        limit = config.loadLimit == nil ? balanceAmount : nil
        // A withdrawal debits Perps dollars whatever the payout token, so typed dollars stay; a token
        // entry resets, since the new token may have no price to reprice it with.
        if !debitsInUsd || input.unit == .token {
            input = PerpsFundingAmountInput(
                tokenDecimals: config.asset().decimals,
                unit: config.initialUnit,
                usdPrice: config.fixedUsdPrice ?? balance?.usdPrice
            )
        }
        self.destination = nil
        if let destination { destinationDidLoad(destination) }
        onAppear()
    }

    func onAppear() {
        isOnScreen = true
        guard loadTask == nil else { return }
        isBalanceLoadInFlight = true
        isLimitLoading = config.loadLimit != nil
        loadTask = Task { [weak self, config, loadPendingReview] in
            if let loadPendingReview {
                do {
                    let pending = try await PerpsOperationLog.step("pending_review", fields: ["flow": config.flow, "asset_id": config.asset().assetId]) {
                        try await loadPendingReview()
                    }
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
            async let iconURL = config.loadIcon?()
            async let balance = config.loadBalance()
            async let limit = config.loadLimit?()
            async let minimum = config.loadMinimum?()
            async let destination = config.loadDestination?()
            let loadedBalance = await balance
            guard !Task.isCancelled, let self else { return }
            self.balance = loadedBalance.map {
                PerpsFundingBalance(amount: $0.amount, usdPrice: $0.usdPrice, iconURL: $0.iconURL ?? self.balance?.iconURL)
            }
            if config.fixedUsdPrice == nil {
                input.setUsdPrice(loadedBalance?.usdPrice)
            }
            if config.loadLimit == nil {
                self.limit = loadedBalance.flatMap { PerpsFundingAmountInput.decimal($0.amount) }
            }
            // Available is the balance itself here: the fee reserve only prices Max.
            if config.limitIsMaxOnly {
                isBalanceLoadInFlight = false
            }
            let loadedLimit = await limit
            guard !Task.isCancelled else { return }
            if config.loadLimit != nil {
                self.limit = loadedLimit.flatMap(PerpsFundingAmountInput.decimal)
            }
            isLimitLoading = false
            isBalanceLoadInFlight = false
            if isMaxPending {
                isMaxPending = false
                if isMaxEnabled { setMax() }
            }
            do {
                let loadedMinimum = try await minimum
                guard !Task.isCancelled else { return }
                self.minimum = loadedMinimum
            } catch {
                guard !Task.isCancelled else { return }
                if pendingReview == nil, leavesForRegion(error) { return }
                let assetId = config.asset().assetId
                let isNewBlock = blockedAssets[assetId] == nil
                if remembersBlock(error, of: assetId), isNewBlock, pendingReview == nil, !reportedBackgroundBlock {
                    reportedBackgroundBlock = true
                    config.report?(.blockedInBackground)
                }
            }
            if let loadedDestination = await destination {
                guard !Task.isCancelled else { return }
                destinationDidLoad(loadedDestination)
            }
            if loadPreferredAsset != nil {
                let preferred = await preferredAsset
                guard !Task.isCancelled else { return }
                if let preferred { startsFrom(preferred) }
                isAssetChosen = true
            }
            let loadedIcon = await iconURL
            guard !Task.isCancelled, let loadedIcon, let balance = self.balance else { return }
            self.balance = PerpsFundingBalance(amount: balance.amount, usdPrice: balance.usdPrice, iconURL: loadedIcon)
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
        if !text.isEmpty { isAssetChosen = true }
        input.setText(text)
        errorText = nil
        isMaxPending = false
    }

    func toggleUnit() {
        guard canToggleUnit else { return }
        input.toggleUnit()
    }

    func setMax() {
        guard let limit else {
            isMaxPending = isMaxEnabled
            return
        }
        if debitsInUsd {
            input.setMaxUsd(limit)
        } else {
            input.setMax(limit)
        }
        errorText = nil
    }

    func review() {
        guard isReviewEnabled else { return }
        if let pendingReview {
            onReviewed?(pendingReview)
            return
        }
        config.report?(.reviewTapped(usdAmount: input.usdAmount))
        if var quoted = reusableQuote {
            quoted.isUsed = true
            liveQuote = .quoted(quoted)
            onReviewed?(quoted.reviewed)
            return
        }
        guard let amount = debitAmount else { return }
        reviewTask?.cancel()
        isReviewInFlight = true
        errorText = nil
        let amountText = PerpsFundingAmountInput.text(amount)
        let key = quoteKey
        let assetId = config.asset().assetId
        reviewTask = Task { [weak self, config] in
            do {
                let reviewed = try await PerpsOperationLog.step("review_input", fields: ["flow": config.flow, "asset_id": config.asset().assetId, "amount": amountText]) {
                    try await config.review(amountText)
                }
                guard !Task.isCancelled, let self else { return }
                self.isReviewInFlight = false
                // A block found meanwhile refuses every amount, this one too.
                guard self.blockedAssets[assetId] == nil else { return }
                if let key, key == self.quoteKey, let quote = config.quote?(reviewed) {
                    self.liveQuote = .quoted(Quoted(key: key, reviewed: reviewed, quote: quote, isUsed: true))
                }
                self.onReviewed?(reviewed)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isReviewInFlight = false
                if self.leavesForRegion(error) { return }
                if self.remembersBlock(error, of: assetId) { return }
                guard self.blockedAssets[assetId] == nil else { return }
                self.errorText = config.errorText(error)
                config.report?(.failed(error))
            }
        }
    }

    func reportRefusal() async {
        guard refusal != nil, let key = refusalKey else {
            reportedRefusalKey = nil
            return
        }
        guard key != reportedRefusalKey else { return }
        do {
            try await Task.sleep(nanoseconds: UInt64(quoteDebounce * 1_000_000_000))
        } catch {
            return
        }
        reportShownRefusal()
    }

    /// Once per amount; a tap that leaves the screen reports it without waiting for the pause.
    private func reportShownRefusal() {
        guard let refusal, let key = refusalKey, key != reportedRefusalKey else { return }
        reportedRefusalKey = key
        config.report?(.refused(refusal))
    }

    /// Runs whenever `quoteKey` changes; a newer run cancels it.
    func updateQuote() async {
        guard let readQuote = config.quote, let key = quoteKey, let amount = debitAmount else {
            liveQuote = nil
            return
        }
        guard reusableQuote == nil else { return }
        liveQuote = nil
        let amountText = PerpsFundingAmountInput.text(amount)
        let assetId = config.asset().assetId
        do {
            try await Task.sleep(nanoseconds: UInt64(quoteDebounce * 1_000_000_000))
            let reviewed = try await config.review(amountText)
            guard !Task.isCancelled, !showsQuote(of: key) else { return }
            if let quote = readQuote(reviewed) {
                liveQuote = .quoted(Quoted(key: key, reviewed: reviewed, quote: quote))
            } else {
                liveQuote = .failed(key: key, text: TKLocales.Perps.DepositForm.quoteFailed)
                config.report?(.unreadableQuote)
            }
        } catch {
            guard !Task.isCancelled, !showsQuote(of: key) else { return }
            if leavesForRegion(error) { return }
            if remembersBlock(error, of: assetId) { return }
            liveQuote = .failed(key: key, text: config.errorText(error) ?? TKLocales.Perps.DepositForm.quoteFailed)
            config.report?(.failed(error))
        }
    }

    private func leavesForRegion(_ error: Error) -> Bool {
        guard config.isRegionRestricted?(error) == true else { return false }
        if isOnScreen {
            isOnScreen = false
            onRegionRestricted?()
        }
        return true
    }

    /// The block itself is reported as a refusal of the amount, after the same pause as the others.
    private func remembersBlock(_ error: Error, of assetId: String) -> Bool {
        guard config.blocksAsset?(error) == true, let text = config.errorText(error) else { return false }
        blockedAssets[assetId] = text
        if assetId == config.asset().assetId, blockText != nil { errorText = nil }
        return true
    }

    /// Review prices on its own while this quote is on the way; the line then keeps what the confirmation shows.
    private func showsQuote(of key: String) -> Bool {
        guard case let .quoted(quoted) = liveQuote else { return false }
        return quoted.key == key
    }

    func addFunds() {
        onAddFunds?()
    }

    func chooseAnotherWallet() {
        guard offersAnotherWallet else { return }
        reportShownRefusal()
        onChooseAnotherWallet?()
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
        isOnScreen = false
        loadTask?.cancel()
        loadTask = nil
        reviewTask?.cancel()
        reviewTask = nil
        isReviewInFlight = false
        pendingReview = nil
        isMaxPending = false
        isLimitLoading = false
        isBalanceLoadInFlight = false
    }

    /// The entry's token turns into the destination's, keeping dollars already typed.
    private func destinationDidLoad(_ loaded: PerpsDepositSourceOption) {
        guard debitsInUsd else { return }
        let isRepricing = destinationPrice != nil
            && destination?.source.assetId.lowercased() == loaded.source.assetId.lowercased()
        destination = loaded
        guard let price = destinationPrice else { return }
        if isRepricing {
            input.setUsdPrice(price)
        } else {
            input = input.repriced(tokenDecimals: loaded.source.decimals, usdPrice: price)
        }
    }

    private func tokenText(_ amount: Decimal) -> String {
        format.tokenCompact(amount, symbol: symbol)
    }

    private func usdText(_ value: Decimal) -> String {
        format.usd(PerpsFundingAmountInput.text(value))
    }

    /// Cents, as the fee is an estimate; a fee under a cent keeps its digits rather than show $0.
    private func feeText(_ value: Decimal) -> String {
        guard abs(value) >= 0.01 else { return usdText(value) }
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return usdText(rounded)
    }
}

typealias PerpsDepositAmountViewModel = PerpsFundingAmountViewModel<PerpsReviewedDeposit>
typealias PerpsWithdrawAmountViewModel = PerpsFundingAmountViewModel<PerpsReviewedWithdraw>

extension PerpsFormatting {
    /// "0.0000356 BTC · $3.56"; dollars only where the asset has a price.
    func fundingBalance(_ balance: PerpsFundingBalance, symbol: String) -> String? {
        guard let amount = PerpsFundingAmountInput.decimal(balance.amount) else { return nil }
        if let hidden = hiddenBalanceText { return hidden }
        let token = tokenCompact(amount, symbol: symbol)
        guard let price = balance.usdPrice else { return token }
        return "\(token) · \(usd(PerpsFundingAmountInput.text(amount * price)))"
    }
}

enum PerpsFundingText {
    /// A field the design asks for with no source behind it yet.
    static let missing = "—"
}
