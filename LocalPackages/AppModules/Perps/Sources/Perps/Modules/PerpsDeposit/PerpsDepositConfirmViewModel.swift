import Combine
import Foundation
import PerpsModels
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class PerpsDepositConfirmViewModel: PerpsTradeConfirmViewModeling {
    @Published private(set) var errorText: String?
    @Published private var reviewed: PerpsReviewedDeposit
    @Published private var isPaying = false
    @Published private var isRequoting = false

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var onPaid: ((PerpsDepositOutcome) -> Void)?

    private let walletName: String
    private let source: PerpsDepositSource
    private let balance: PerpsFundingBalance?
    private let format: PerpsFormatting
    private let message: (Error) -> PerpsDepositMessage
    private let passcodeProvider: () async -> String?
    /// `nil` for a payment being finished: it pays the terms it was signed with.
    private let requote: (() async throws -> PerpsReviewedDeposit)?
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private var requoteTask: Task<Void, Never>?
    /// A payment that failed for any reason but an expired quote may have reached the chain, and
    /// its retry is matched to it by the quote, so that quote is no longer replaced.
    private var keepsQuote = false

    /// How long before expiry a quote is replaced, so a confirmation does not start on one about to lapse.
    static let requoteLead: TimeInterval = 5

    init(
        reviewed: PerpsReviewedDeposit,
        walletName: String,
        source: PerpsDepositSource,
        balance: PerpsFundingBalance?,
        format: PerpsFormatting,
        message: @escaping (Error) -> PerpsDepositMessage,
        passcodeProvider: @escaping () async -> String?,
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
        self.passcodeProvider = passcodeProvider
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

    private var terms: PerpsDepositTerms {
        reviewed.terms
    }

    var titleText: String {
        "\(TKLocales.Perps.deposit) \(terms.sourceSymbol)"
    }

    var titleSuffixText: String? {
        source.network.displayName
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
                title: TKLocales.Perps.totalAmount,
                value: "\(terms.sourceAmount) \(terms.sourceSymbol)",
                subValue: PerpsFundingConfirmRows.usd(terms.sourceAmount, price: balance?.usdPrice, format: format)
            ),
        ]
        // Registration alone adds no network fee; an unfinished payment may still need gas.
        if !terms.resumesPayment || terms.expiresAt != nil {
            rows.append(PerpsFundingConfirmRows.networkFee(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
                fee: terms.networkFee,
                symbol: terms.networkFeeSymbol,
                usd: terms.networkFeeUsd,
                format: format
            ))
        }
        rows.append(PerpsTradeConfirmRow(
            id: .minReceived,
            title: TKLocales.Perps.Confirm.minReceived,
            value: format.usd(terms.creditedAmount),
            subValue: nil
        ))
        if let seconds = terms.estimatedDurationSeconds {
            rows.append(PerpsFundingConfirmRows.arrivalTime(seconds: seconds))
        }
        return rows
    }

    /// The delegation is said whenever confirming would sign it, an error above it included:
    /// a requote that first brings it in keeps its "check the amount again".
    var noticeText: String? {
        let delegation = terms.delegatedNetworks.isEmpty ? nil : TKLocales.Perps.DepositForm.delegationNotice(
            terms.delegatedNetworks.map(\.displayName).joined(separator: ", ")
        )
        if let errorText { return [errorText, delegation].compactMap { $0 }.joined(separator: "\n") }
        if terms.resumesPayment { return TKLocales.Perps.DepositForm.resumingPayment }
        let notices = [highFeeNotice, delegation].compactMap { $0 }
        return notices.isEmpty ? nil : notices.joined(separator: "\n")
    }

    var isNoticeError: Bool {
        errorText != nil
    }

    var isNoticeWarning: Bool {
        errorText == nil && !terms.resumesPayment && highFeeNotice != nil
    }

    /// The fee is what the source is worth beyond the USDC it credits, plus the network fee.
    private var highFeeNotice: String? {
        guard let price = balance?.usdPrice,
              let spent = PerpsFundingAmountInput.decimal(terms.sourceAmount).map({ $0 * price }),
              let credited = PerpsFundingAmountInput.decimal(terms.creditedAmount)
        else { return nil }
        return PerpsFundingConfirmRows.highFeeNotice(fee: spent - credited + (terms.networkFeeUsd ?? 0), of: spent)
    }

    func onAppear() {
        scheduleRequote()
    }

    func onDisappear() {
        cancelRequote()
    }

    func editAutoClose() {}

    func confirm() {
        guard isConfirmationEnabled else { return }
        if let expiresAt = terms.expiresAt, expiresAt <= now() {
            let expired = PerpsDepositErrorText.text(for: .quoteExpired, format: format)
            if canRequote { requoteNow(notice: expired) } else { errorText = expired }
            return
        }
        cancelRequote()
        isPaying = true
        errorText = nil
        Task { [weak self, reviewed, message, passcodeProvider, format] in
            guard let passcode = await passcodeProvider() else {
                self?.isPaying = false
                self?.scheduleRequote()
                return
            }
            do {
                let outcome = try await reviewed.pay(passcode)
                self?.isPaying = false
                self?.onPaid?(outcome)
            } catch {
                Log.w("🪵 Perps deposit: payment failed", error: error)
                guard let self else { return }
                isPaying = false
                let failure = message(error)
                let text = PerpsDepositErrorText.text(for: failure, format: format)
                if failure == .quoteExpired, canRequote {
                    requoteNow(notice: text)
                } else {
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
            Log.w("🪵 Perps deposit: requote failed", error: error)
            errorText = PerpsDepositErrorText.text(for: message(error), format: format)
            isRequoting = false
        }
    }
}
