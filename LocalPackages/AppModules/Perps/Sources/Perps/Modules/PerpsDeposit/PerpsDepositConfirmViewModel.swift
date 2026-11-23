import AppUI
import Combine
import Foundation
import OperationReviewModels
import PerpsModels
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class PerpsDepositConfirmViewModel: PerpsTradeConfirmViewModeling {
    @Published private(set) var errorText: String?
    @Published private var reviewed: PerpsReviewedDeposit {
        didSet {
            reviewGeneration += 1
            if hasAppeared, oldValue.terms.feeShortageSymbol == nil { reportFeeShortage() }
        }
    }

    @Published private var isPaying = false
    @Published private var isRequoting = false

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var onPaid: ((PerpsDepositOutcome) -> Void)?
    var onConfirmed: ((_ operationId: String) -> Void)?
    var onFailure: ((PerpsDepositMessage) -> Void)?

    private let walletName: String
    private let source: PerpsDepositSource
    private let balance: PerpsFundingBalance?
    private let format: PerpsFormatting
    private let message: (Error) -> PerpsDepositMessage
    private let hasOtherWallets: Bool
    private let passcodeProvider: () async -> String?
    /// A fresh consent for each confirm attempt.
    private let consent: @MainActor () -> OperationConsent
    /// `nil` for a payment being finished: it pays the terms it was signed with.
    private let requote: (() async throws -> PerpsReviewedDeposit)?
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private(set) var requoteTask: Task<Void, Never>?
    /// Tells a fee picked on one review from a requote that replaced it while the picker was open.
    private var reviewGeneration = 0
    /// A payment that failed for any reason but an expired or changed quote may have reached the chain, and
    /// its retry is matched to it by the quote, so that quote is no longer replaced.
    private var keepsQuote = false
    private var hasAppeared = false

    /// How long before expiry a quote is replaced, so a confirmation does not start on one about to lapse.
    static let requoteLead: TimeInterval = 5

    init(
        reviewed: PerpsReviewedDeposit,
        walletName: String,
        source: PerpsDepositSource,
        balance: PerpsFundingBalance?,
        format: PerpsFormatting,
        message: @escaping (Error) -> PerpsDepositMessage,
        hasOtherWallets: Bool = true,
        passcodeProvider: @escaping () async -> String?,
        consent: @escaping @MainActor () -> OperationConsent,
        requote: (() async throws -> PerpsReviewedDeposit)? = nil,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    ) {
        self.reviewed = reviewed
        self.walletName = walletName
        self.source = source
        self.balance = balance
        self.format = format
        self.message = message
        self.hasOtherWallets = hasOtherWallets
        self.passcodeProvider = passcodeProvider
        self.consent = consent
        self.requote = requote
        self.now = now
        self.sleep = sleep
    }

    deinit {
        requoteTask?.cancel()
    }

    var isConfirmationEnabled: Bool {
        !isPaying && !isRequoting
    }

    var isProcessing: Bool {
        isPaying
    }

    var confirmAppearance: TKSlider.Appearance {
        TKSlider.Appearance(review: reviewed.review)
    }

    private var terms: PerpsDepositTerms {
        reviewed.terms
    }

    private var sentAmount: String {
        terms.sentAmount ?? terms.sourceAmount
    }

    var titleText: String {
        "\(TKLocales.Perps.deposit) \(terms.sourceSymbol)"
    }

    var titleSuffixText: String? {
        let network = source.network.displayName
        return network == terms.sourceSymbol ? nil : network
    }

    var iconLetter: String {
        String(terms.sourceSymbol.prefix(1))
    }

    var iconURL: URL? {
        balance?.iconURL
    }

    var iconChainImage: UIImage? {
        source.network.chainIcon
    }

    var rows: [PerpsTradeConfirmRow] {
        var rows = [
            PerpsTradeConfirmRow(id: .wallet, title: TKLocales.ConfirmSend.wallet, value: walletName, subValue: nil),
            PerpsTradeConfirmRow(
                id: .totalAmount,
                title: TKLocales.Perps.Funding.youSend,
                value: "\(format.plain(sentAmount)) \(terms.sourceSymbol)",
                subValue: PerpsFundingConfirmRows.usd(sentAmount, price: balance?.usdPrice, format: format)
            ),
            PerpsTradeConfirmRow(
                id: .toPerpsAccount,
                title: TKLocales.Perps.Funding.toPerpsAccount,
                value: "≈ \(format.usd(terms.creditedAmount))",
                subValue: nil
            ),
            PerpsTradeConfirmRow(
                id: .minReceived,
                title: TKLocales.Perps.Confirm.minReceived,
                value: format.usd(terms.creditedAmount),
                subValue: nil
            ),
        ]
        if let provider = terms.provider {
            rows.append(PerpsTradeConfirmRow(
                id: .provider,
                title: TKLocales.NativeSwap.Screen.Confirm.Field.provider,
                value: provider,
                subValue: nil
            ))
        }
        // Registration alone adds no network fee; an unfinished payment may still need gas.
        if !terms.resumesPayment || terms.expiresAt != nil {
            rows += feeRows
        }
        if let seconds = terms.estimatedDurationSeconds {
            rows.append(PerpsFundingConfirmRows.arrivalTime(seconds: seconds, hint: TKLocales.Perps.DepositForm.arrivalTimeInfo))
        }
        return rows
    }

    /// The delegation is said whenever confirming would sign it, an error above it included:
    /// a requote that first brings it in keeps its "check the amount again".
    var noticeText: String? {
        let delegation = terms.delegatedNetworks.isEmpty ? nil : TKLocales.Perps.DepositForm.delegationNotice(
            terms.delegatedNetworks.map(\.displayName).joined(separator: ", ")
        )
        if let error = errorText ?? feeShortageText { return [error, delegation].compactMap { $0 }.joined(separator: "\n") }
        if terms.resumesPayment { return TKLocales.Perps.DepositForm.resumingPayment }
        let notices = [highFeeNotice, delegation].compactMap { $0 }
        return notices.isEmpty ? nil : notices.joined(separator: "\n")
    }

    var isNoticeError: Bool {
        errorText != nil || feeShortageText != nil
    }

    var isNoticeWarning: Bool {
        !isNoticeError && !terms.resumesPayment && highFeeNotice != nil
    }

    private var feeShortageText: String? {
        terms.feeShortageSymbol.map(TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken)
    }

    /// The Fees row's value and its second line, and the hint's two lines: the gas on both chains,
    /// and what the provider keeps. A picked token with no dollar price leads the row as it is, with
    /// the rest of the fee in dollars under it.
    private var fees: (value: String, subValue: String?, network: String, provider: String)? {
        guard let providerFees = terms.providerFees else { return nil }
        let provider = providerFees.providerUsd
        if let networkFeeUsd = terms.networkFeeUsd {
            let network = networkFeeUsd + providerFees.destinationGasUsd
            return ("≈ \(usd(network + provider))", nil, usd(network), usd(provider))
        }
        guard terms.feeMethodTitle != nil,
              let units = terms.networkFee.flatMap(PerpsFundingAmountInput.decimal)
        else { return nil }
        let amount = format.tokenCompact(units, symbol: terms.networkFeeSymbol)
        let gas = providerFees.destinationGasUsd
        let network = gas > 0 ? "\(usd(gas)) + \(amount)" : amount
        let dollars = gas + provider
        return (amount, dollars > 0 ? "+ \(usd(dollars))" : nil, network, usd(provider))
    }

    private var feeRows: [PerpsTradeConfirmRow] {
        if terms.paysFeeInCharges { return chargeFeeRows }
        guard let fees else { return [networkFeeRow] }
        return [feeRow(title: TKLocales.Perps.Funding.fees, value: fees.value, subValue: fees.subValue, hint: feeHint(network: fees.network, provider: fees.provider))]
    }

    /// Charges pay the source chain's fee alone, so they stand apart from the dollars of the delivery and
    /// of the provider, and from what Battery holds for the time of the deposit. The account setup is
    /// not paid in charges, so their row never names it.
    /// An existing account is credited without a call on Ethereum, so the delivery gas of the deposit
    /// that creates the account is the price of the setup: it gets its own row.
    private var chargeFeeRows: [PerpsTradeConfirmRow] {
        let charges = terms.networkFee.flatMap(PerpsFundingAmountInput.decimal)
            .map { "≈ \(format.tokenCompact($0, symbol: terms.networkFeeSymbol))" } ?? PerpsFundingText.missing
        var rows = [feeRow(title: TKLocales.Perps.DepositForm.networkFees, value: charges, subValue: nil, hint: nil)]
        if let providerFees = terms.providerFees {
            let gas = providerFees.destinationGasUsd
            if terms.createsAccount, gas > 0 {
                rows.append(PerpsTradeConfirmRow(
                    id: .activationFee,
                    title: TKLocales.Perps.DepositForm.activationFee,
                    value: "≈ \(format.tokenCompact(gas, symbol: terms.creditedSymbol))",
                    subValue: nil,
                    titleHint: TKLocales.Perps.DepositForm.activationFeeInfo
                ))
            }
            let dollars = terms.createsAccount ? providerFees.providerUsd : gas + providerFees.providerUsd
            if dollars > 0 {
                rows.append(PerpsTradeConfirmRow(
                    id: .providerFee,
                    title: TKLocales.Perps.Funding.fees,
                    value: "≈ \(usd(dollars))",
                    subValue: nil,
                    titleHint: terms.createsAccount ? nil : TKLocales.Perps.DepositForm.feeDetails(usd(gas), usd(providerFees.providerUsd))
                ))
            }
        }
        if let reserve = terms.networkFeeReserve {
            rows.append(PerpsTradeConfirmRow(
                id: .temporaryReserve,
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.temporaryReserve,
                value: "≈ \(reserve)",
                subValue: nil,
                titleHint: TKLocales.Perps.DepositForm.temporaryReserveInfo(reserve)
            ))
        }
        return rows
    }

    /// Either part unknown, the sum would understate the fee, so the row names the network fee alone.
    private var networkFeeRow: PerpsTradeConfirmRow {
        let row = PerpsFundingConfirmRows.networkFee(
            title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            fee: terms.networkFee,
            symbol: terms.networkFeeSymbol,
            usd: terms.networkFeeUsd,
            format: format
        )
        guard canPickFee else {
            return PerpsTradeConfirmRow(id: row.id, title: row.title, value: row.value, subValue: row.subValue, tone: row.tone, titleHint: activationNote)
        }
        return PerpsTradeConfirmRow(id: row.id, title: row.title, value: row.value, subValue: nil, titleHint: activationNote, showsFeePicker: true, feeMethod: terms.feeMethodTitle)
    }

    /// The row the fee picker opens from, followed by what pays the fee.
    private func feeRow(title: String, value: String, subValue: String?, hint: String?) -> PerpsTradeConfirmRow {
        let method = terms.feeMethodTitle ?? terms.networkFeeSymbol
        if canPickFee {
            return PerpsTradeConfirmRow(id: .fee, title: title, value: value, subValue: subValue, titleHint: hint, showsFeePicker: true, feeMethod: method)
        }
        return PerpsTradeConfirmRow(
            id: .fee,
            title: title,
            value: "\(value) · \(method)",
            valueParts: [
                .init(text: "\(value) · ", tone: .neutral),
                .init(text: method, tone: .accent),
            ],
            subValue: subValue,
            titleHint: hint
        )
    }

    /// The first deposit's gas also sets up the Lighter account.
    private func feeHint(network: String, provider: String) -> String {
        terms.createsAccount
            ? TKLocales.Perps.DepositForm.activationFeeDetails(network, provider)
            : TKLocales.Perps.DepositForm.feeDetails(network, provider)
    }

    private var activationNote: String? {
        terms.createsAccount ? TKLocales.Perps.DepositForm.accountSetupNote : nil
    }

    private var canPickFee: Bool {
        reviewed.pickFee != nil && !terms.resumesPayment
    }

    /// Known fees can already exceed the threshold even when another part is unpriced.
    private var highFeeNotice: String? {
        guard let price = balance?.usdPrice else { return nil }
        let providerFees = terms.providerFees.map { $0.destinationGasUsd + $0.providerUsd } ?? 0
        return PerpsFundingConfirmRows.highFeeNotice(
            fee: (terms.networkFeeUsd ?? 0) + providerFees,
            of: PerpsFundingAmountInput.decimal(terms.sourceAmount).map { $0 * price }
        )
    }

    private func reportFeeShortage() {
        guard let symbol = terms.feeShortageSymbol else { return }
        onFailure?(.insufficientNetworkFee(symbol: symbol))
    }

    private func usd(_ value: Decimal) -> String {
        format.usd(NSDecimalNumber(decimal: value).doubleValue)
    }

    func onAppear() {
        if !hasAppeared {
            hasAppeared = true
            reportFeeShortage()
        }
        scheduleRequote()
    }

    func onDisappear() {
        cancelRequote()
    }

    func editAutoClose() {}

    func pickFee() {
        guard isConfirmationEnabled, canPickFee, let pick = reviewed.pickFee else { return }
        let generation = reviewGeneration
        pick { [weak self] picked in
            guard let self else { return }
            // A top-up, or a requote that replaced the review meanwhile: asking again prices the
            // methods on what the wallet holds now.
            guard let picked, generation == reviewGeneration else {
                requoteNow(notice: nil)
                return
            }
            reviewed = picked
            errorText = nil
        }
    }

    func confirm() {
        guard isConfirmationEnabled else { return }
        // Nothing covers the fee: the picker is where each method is topped up.
        if feeShortageText != nil, canPickFee {
            pickFee()
            return
        }
        if refusesExpiredQuote() { return }
        cancelRequote()
        isPaying = true
        errorText = nil
        let consent = self.consent()
        Task { [weak self, source, reviewed, message, passcodeProvider, format] in
            if let review = reviewed.review, await !consent(review) {
                PerpsOperationLog.event("review", outcome: "declined", source: "user", fields: ["flow": "deposit", "asset_id": source.assetId])
                self?.isPaying = false
                self?.scheduleRequote()
                return
            }
            // The findings may have been read past the quote.
            if self?.refusesExpiredQuote() == true { return }
            guard let passcode = await passcodeProvider() else {
                PerpsOperationLog.event("unlock", outcome: "cancelled", source: "user", fields: ["flow": "deposit", "asset_id": source.assetId])
                self?.isPaying = false
                self?.scheduleRequote()
                return
            }
            do {
                let outcome = try await reviewed.pay(passcode, consent)
                self?.isPaying = false
                if case .registered = outcome {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                if !reviewed.terms.resumesPayment {
                    self?.onConfirmed?(outcome.operationId)
                }
                self?.onPaid?(outcome)
            } catch {
                PerpsOperationLog.event("confirm", outcome: "failed", error: error, fields: ["flow": "deposit", "asset_id": source.assetId])
                guard let self else { return }
                let failure = message(error)
                isPaying = failure == .regionRestricted
                // A declined review wrote no deposit, so the quote may still be replaced. The account
                // binding the payment made first stays: every deposit needs it, and it is made once.
                if failure == .canceled {
                    scheduleRequote()
                    return
                }
                onFailure?(failure)
                if failure == .regionRestricted { return }
                let text = PerpsDepositErrorText.text(for: failure, format: format, hasOtherWallets: hasOtherWallets)
                if failure == .quoteExpired || failure == .quoteChanged, canRequote {
                    requoteNow(notice: text)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    keepsQuote = true
                    errorText = text
                }
            }
        }
    }

    /// Not while a payment is under way: its outcome would land on a screen nobody sees,
    /// and the amount screen behind this one would offer a second deposit meanwhile.
    func back() {
        guard !isPaying else { return }
        onBack?()
    }

    func close() {
        guard !isPaying else { return }
        onClose?()
    }

    private var canRequote: Bool {
        requote != nil && !keepsQuote
    }

    /// A lapsed quote is not paid: it is replaced when it can be, and named otherwise.
    private func refusesExpiredQuote() -> Bool {
        guard let expiresAt = terms.expiresAt, expiresAt <= now() else { return false }
        isPaying = false
        onFailure?(.quoteExpired)
        let expired = PerpsDepositErrorText.text(for: .quoteExpired, format: format)
        if canRequote { requoteNow(notice: expired) } else { errorText = expired }
        return true
    }

    private func scheduleRequote() {
        cancelRequote()
        guard canRequote, !isPaying, let expiresAt = terms.expiresAt else { return }
        let remaining = expiresAt.timeIntervalSince(now())
        // A quote shorter-lived than the lead is still replaced halfway rather than continuously.
        let delay = max(remaining - Self.requoteLead, remaining / 2, 0)
        requoteTask = Task { [weak self, sleep] in
            do { try await sleep(delay) } catch { return }
            await self?.performRequote(notice: nil)
        }
    }

    private func requoteNow(notice: String?) {
        cancelRequote()
        requoteTask = Task { [weak self] in await self?.performRequote(notice: notice) }
    }

    /// A cancelled requote applies nothing, so whatever it held is released here.
    private func cancelRequote() {
        requoteTask?.cancel()
        requoteTask = nil
        isRequoting = false
    }

    private func performRequote(notice: String?) async {
        guard let requote, !Task.isCancelled else { return }
        isRequoting = true
        do {
            let fresh = try await requote()
            guard !Task.isCancelled else { return }
            if let expiresAt = fresh.terms.expiresAt, expiresAt <= now() {
                onFailure?(.quoteExpired)
                errorText = PerpsDepositErrorText.text(for: .quoteExpired, format: format)
                isRequoting = false
                return
            }
            reviewed = fresh
            errorText = notice
            isRequoting = false
            scheduleRequote()
        } catch {
            guard !Task.isCancelled else { return }
            // Not rescheduled: a confirmation on the lapsed quote asks again, and nothing loops meanwhile.
            PerpsOperationLog.event("requote", outcome: "failed", error: error, fields: ["flow": "deposit", "asset_id": source.assetId])
            let failure = message(error)
            onFailure?(failure)
            errorText = PerpsDepositErrorText.text(for: failure, format: format, hasOtherWallets: hasOtherWallets)
            isRequoting = false
        }
    }
}
