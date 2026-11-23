import AppUI
import Foundation
import KeeperCore
import MoonPay
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class MoonPayPaymentStatusViewModel: ObservableObject {
    enum Retry {
        case anotherCard
        case changeAmount
        case again
    }

    enum Failure: Equatable {
        case declined
        case dailyLimit
        case notConfirmed
        case unavailable
        case generic

        init(_ error: MoonPayRampError) {
            switch error {
            case let .payment(code, _):
                self = Self(paymentCode: code)
            case .frame, .notConfigured, .verificationFailed, .signInRequired:
                self = .unavailable
            case .paymentCancelled, .challengeCancelled, .verificationCancelled, .quoteNotExecutable, .paymentFrameError:
                self = .generic
            }
        }

        /// MoonPay's code for a failed payment: a widget or Apple Pay frame's `failureCode`
        /// (camelCase) or a failed transaction stage's `failureReason` (snake_case). The codes are
        /// the ones Android's `MoonPayPaymentFailures` reads for these failures; a code Android
        /// reads for a failure this screen has no text of its own for, such as a KYC rejection or
        /// a rejected quote, stays generic.
        init(paymentCode code: String?) {
            switch code {
            case "authorizationDeclined", "transactionDeclined",
                 "payment_authorization_declined", "card_not_supported", "rejected_card":
                self = .declined
            case "daily_purchase_limit_exceeded":
                self = .dailyLimit
            case "timeout_3d_secure", "timeout_card_verification", "timeout_bank_transfer", "timeout_kyc_verification":
                self = .notConfirmed
            case "serviceUnavailable", "applePayMerchantUnavailable", "error":
                self = .unavailable
            default:
                self = .generic
            }
        }

        var retry: Retry {
            switch self {
            case .declined: .anotherCard
            case .dailyLimit: .changeAmount
            case .notConfirmed, .unavailable, .generic: .again
            }
        }
    }

    private enum Phase: Equatable {
        case starting
        case started(MoonPayTransaction)
        case pending(MoonPayTransaction)
        case completed(MoonPayTransaction)
        case stillProcessing(MoonPayTransaction)
        case failed(Failure, afterStart: Bool)
        /// After the start MoonPay took the payment, so the open question is only how it ended.
        case unknown(afterStart: Bool)
    }

    private enum StepID: String {
        case started
        case pending
        case completed
    }

    private enum SummaryID: String {
        case paid
        case receive
        case order
    }

    var onClose: (() -> Void)?
    var onRetry: ((Retry) -> Void)?
    /// The user backed out before any payment was made, so there is no status to show.
    var onCancel: (() -> Void)?
    /// How the payment ended, once: when the sheet learns it, or when it closes before.
    var onOutcome: ((DepositRampResult.Outcome, DepositRampResult.FailureReason?) -> Void)?
    private var isOutcomeReported = false
    /// The payment reached MoonPay: its widget opened, a card's payment went out, or the Apple Pay
    /// button was pressed, which is what opens this sheet for it.
    private var isPaymentOpened: Bool

    @Published private var phase: Phase = .starting

    private let quote: MoonPayBuyQuote
    @Published private var paymentTitle: String
    private let formatReceived: ((Decimal) -> String)?
    private let titleForMethod: (String) -> String?
    private let makeUpdates: () -> AsyncStream<MoonPayPaymentUpdate>
    private var task: Task<Void, Never>?
    private var transaction: MoonPayTransaction?

    /// `formatReceived` writes the amount received as the app names the asset: MoonPay's own codes,
    /// such as `USDT_TON`, are not for the user. Without it the quote's amount and code show as sent.
    init(
        quote: MoonPayBuyQuote,
        paymentTitle: String,
        formatReceived: ((Decimal) -> String)? = nil,
        titleForMethod: @escaping (String) -> String?,
        isPaymentOpened: Bool = false,
        updates makeUpdates: @escaping () -> AsyncStream<MoonPayPaymentUpdate>
    ) {
        self.isPaymentOpened = isPaymentOpened
        self.quote = quote
        self.paymentTitle = paymentTitle
        self.formatReceived = formatReceived
        self.titleForMethod = titleForMethod
        self.makeUpdates = makeUpdates
    }

    deinit {
        task?.cancel()
    }

    func start() {
        guard task == nil else { return }
        let updates = makeUpdates()
        task = Task { [weak self] in
            for await update in updates {
                guard let self, !Task.isCancelled else { return }
                apply(update)
            }
        }
    }

    /// Called by the payment as its frame starts, before any update reaches the sheet: a close
    /// right after it must not read as the customer's cancel.
    func paymentDidOpen() {
        isPaymentOpened = true
    }

    func close() {
        task?.cancel()
        sheetDidClose()
        onClose?()
    }

    /// The sheet is gone, by its close button, a swipe or the ramp closing: without an outcome
    /// yet, as Android reports it. Closed before the payment reached MoonPay, the customer cancelled;
    /// while MoonPay processes the payment, it is pending; otherwise nobody learns how it ended.
    func sheetDidClose() {
        switch phase {
        case .starting:
            report(isPaymentOpened ? .unknown : .cancelled)
        case .pending, .stillProcessing:
            report(.pending)
        case .started, .completed, .failed, .unknown:
            report(.unknown)
        }
    }

    private func report(_ outcome: DepositRampResult.Outcome, _ failureReason: DepositRampResult.FailureReason? = nil) {
        guard !isOutcomeReported else { return }
        isOutcomeReported = true
        onOutcome?(outcome, failureReason)
    }

    func copy(_ value: String) {
        UIPasteboard.general.string = value
        ToastPresenter.showToast(configuration: .copied)
    }

    func tapAction() {
        guard case let .failed(failure, _) = phase else { return }
        task?.cancel()
        onRetry?(failure.retry)
    }

    var screenState: MoonPayPaymentStatusViewState {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        let receive = receivedText
        return MoonPayPaymentStatusViewState(
            title: Status.title,
            steps: steps(receive: receive),
            summary: [
                .init(id: SummaryID.paid.rawValue, title: Status.youPaid, value: paidText(quote.source, dropsWholeCents: true)),
                .init(id: SummaryID.receive.rawValue, title: Status.youReceive, value: receive, isHighlighted: true),
                .init(
                    id: SummaryID.order.rawValue,
                    title: Status.orderId,
                    value: transaction?.id ?? "—",
                    isCopyable: transaction?.id != nil
                ),
            ],
            feesTitle: Status.fees,
            feesValue: totalFees(),
            feeDetails: feeRows(),
            showsDetails: !isFailed && phase != .unknown(afterStart: false),
            actionTitle: actionTitle
        )
    }

    private func apply(_ update: MoonPayPaymentUpdate) {
        Log.multichainRamp.i("moonpay status: update", extraInfo: ["update": "\(update)"])
        switch update {
        case let .started(transaction):
            self.transaction = transaction
            phase = .started(transaction)
        case let .pending(transaction):
            self.transaction = transaction
            phase = .pending(transaction)
        case let .completed(transaction):
            self.transaction = transaction
            phase = .completed(transaction)
            report(.success)
        case let .stillProcessing(transaction):
            self.transaction = transaction
            phase = .stillProcessing(transaction)
        case .outcomeUnknown:
            phase = .unknown(afterStart: isStarted)
            report(.unknown)
        case let .paidWith(methodType):
            // The same method keeps the title the user picked, such as a saved card's.
            guard methodType != quote.paymentMethod?.type, let title = titleForMethod(methodType) else { break }
            paymentTitle = title
        case let .failed(error):
            let started = isStarted
            // A 3DS page the customer closed is their cancel even after the start: nothing is
            // charged without it, and they go back to Buy to pay again.
            if (error == .paymentCancelled && !started) || error == .challengeCancelled {
                task?.cancel()
                report(.cancelled)
                onCancel?()
                return
            }
            phase = .failed(Failure(error), afterStart: started)
            report(.failed, DepositRampResult.FailureReason(error))
        }
    }

    private var isStarted: Bool {
        switch phase {
        case .started, .pending, .stillProcessing: true
        default: false
        }
    }

    private func steps(receive: String) -> [MoonPayPaymentStatusViewState.Step] {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        let authorised = "\(paymentTitle) · \(Status.authorised(paidText(quote.source)))"
        var started = step(.started, Status.started, authorised, .waiting)
        var pending = step(.pending, Status.pending, Status.pendingSubtitle, .waiting)
        var completed = step(.completed, Status.completed, Status.completedSubtitle(receive), .waiting)
        switch phase {
        case .starting:
            started.status = .inProgress
        case .started:
            started.status = .done
            pending.status = .inProgress
        case .pending:
            started.status = .done
            pending.status = .done
            completed.status = .inProgress
        case .completed:
            started.status = .done
            pending.status = .done
            completed.status = .done
        case .stillProcessing:
            started.status = .done
            pending.status = .done
            // Polling goes on, so the step keeps its spinner until an outcome or the polling window ends.
            completed = step(.completed, Status.completed, Status.stillProcessingSubtitle, .inProgress)
        case .unknown(afterStart: false):
            started = step(.started, Status.unknownTitle, Status.unknownSubtitle, .failed)
        case .unknown(afterStart: true):
            started.status = .done
            pending.status = .done
            completed = step(.completed, Status.unknownTitle, Status.unknownSubtitle, .failed)
        case let .failed(failure, afterStart):
            let (title, subtitle) = failureText(failure)
            if afterStart {
                started.status = .done
                pending = step(.pending, title, subtitle, .failed)
            } else {
                started = step(.started, title, subtitle, .failed)
            }
        }
        // Past its step, the network has cleared the payment; an unknown outcome confirms nothing.
        if pending.status == .done, phase != .unknown(afterStart: true) {
            pending.subtitle = Status.clearedSubtitle
        }
        return [started, pending, completed]
    }

    private func step(
        _ id: StepID,
        _ title: String,
        _ subtitle: String,
        _ status: MoonPayPaymentStatusViewState.Step.Status
    ) -> MoonPayPaymentStatusViewState.Step {
        .init(id: id.rawValue, title: title, subtitle: subtitle, status: status)
    }

    private func failureText(_ failure: Failure) -> (String, String) {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        switch failure {
        case .declined: return (Status.declinedTitle, Status.declinedSubtitle)
        case .dailyLimit: return (Status.dailyLimitTitle, Status.dailyLimitSubtitle)
        case .notConfirmed: return (Status.notConfirmedTitle, Status.notConfirmedSubtitle)
        case .unavailable: return (Status.unavailableTitle, Status.unavailableSubtitle)
        case .generic: return (Status.failedTitle, Status.failedSubtitle)
        }
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private var actionTitle: String? {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        guard case let .failed(failure, _) = phase else { return nil }
        switch failure.retry {
        case .anotherCard: return Status.tryAnotherCard
        case .changeAmount: return Status.changeAmount
        case .again: return Status.tryAgain
        }
    }

    private var receivedText: String {
        guard let formatReceived,
              let amount = quote.destination.amount.flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) })
        else { return amountText(quote.destination) }
        return formatReceived(amount)
    }

    private func amountText(_ money: MoonPayMoney) -> String {
        let code = (money.asset.code ?? "").uppercased()
        let amount = money.amount ?? "0"
        return code.isEmpty ? amount : "\(amount) \(code)"
    }

    private func totalFees() -> String {
        MoonPayQuoteFees.totalText(of: quote)
    }

    private func feeRows() -> [MoonPayPaymentStatusViewState.SummaryRow] {
        MoonPayQuoteFees.rows(of: quote)
    }

    private func paidText(_ money: MoonPayMoney, dropsWholeCents: Bool = false) -> String {
        guard let amount = money.amount.flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) })
        else { return amountText(money) }
        return Self.paidText(amount, code: money.asset.code, dropsWholeCents: dropsWholeCents)
    }

    /// An amount in the currency paid, as Android writes it: with the currency's symbol, every
    /// digit MoonPay sent but at least the cents ("$200.00", "$13.30"), so the fee rows add up to
    /// their total; `dropsWholeCents` leaves out the cents of a whole amount ("$200").
    nonisolated static func paidText(_ amount: Decimal, code: String?, dropsWholeCents: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        let sentDigits = max(0, -amount.exponent)
        var whole = Decimal()
        var value = amount
        NSDecimalRound(&whole, &value, 0, .down)
        let isWhole = whole == amount
        let fractionDigits = dropsWholeCents && isWhole ? 0 : max(Self.centsDigits, sentDigits)
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let text = formatter.string(from: amount as NSDecimalNumber) ?? NSDecimalNumber(decimal: amount).stringValue
        guard let currency = code.flatMap(Currency.init(code:)) else { return text }
        return currency.symbolOnLeft ? "\(currency.rampSymbol)\(text)" : "\(text)\u{00A0}\(currency.rampSymbol)"
    }

    private nonisolated static let centsDigits = 2
}

extension DepositRampResult.FailureReason {
    /// MoonPay's failure as the deposit funnel names it, from the codes Android reads in
    /// `MoonPayPaymentFailures`.
    init(_ error: MoonPayRampError) {
        switch error {
        case let .payment(code, _):
            self = Self(paymentCode: code)
        case let .paymentFrameError(code, _):
            self = Self(frameErrorCode: code)
        case let .verificationFailed(status):
            switch status {
            case .pending: self = .verificationPending
            case .unavailable, .failed: self = .verificationUnavailable
            case .active, .connectionRequired, .termsAcceptanceRequired: self = .unknown
            }
        case .quoteNotExecutable:
            self = .quoteRejected
        case .frame, .notConfigured:
            self = .unavailable
        case .signInRequired, .verificationCancelled, .paymentCancelled, .challengeCancelled:
            self = .unknown
        }
    }

    /// A frame's transaction `failureCode` or a failed stage's `failureReason`.
    init(paymentCode code: String?) {
        switch code {
        case "authorizationDeclined", "transactionDeclined",
             "payment_authorization_declined", "card_not_supported", "rejected_card":
            self = .declined
        case "daily_purchase_limit_exceeded":
            self = .limitReached
        case "timeout_3d_secure", "timeout_card_verification", "timeout_bank_transfer", "timeout_kyc_verification":
            self = .notConfirmed
        case "validationError":
            self = .quoteRejected
        case "rejected_kyc":
            self = .verificationUnavailable
        case "cancelled":
            self = .transactionCancelled
        case "serviceUnavailable", "applePayMerchantUnavailable", "error":
            self = .unavailable
        default:
            self = .unknown
        }
    }

    /// A payment frame's `error` event.
    init(frameErrorCode code: String?) {
        switch code {
        case "invalidQuote", "quoteExpired", "unsupportedPaymentMethod", "configurationError", "missing_quote":
            self = .quoteRejected
        case "customer_status_pending":
            self = .verificationPending
        case "customer_status_unavailable":
            self = .verificationUnavailable
        case let code? where code.hasPrefix("invalid_"):
            self = .quoteRejected
        default:
            self = .unknown
        }
    }
}
