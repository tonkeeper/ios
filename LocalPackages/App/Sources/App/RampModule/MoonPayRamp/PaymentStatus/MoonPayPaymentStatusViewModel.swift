import AppUI
import Foundation
import MoonPay
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
            case .payment:
                self = .generic
            case .frame, .notConfigured, .verificationFailed:
                self = .unavailable
            case .paymentCancelled, .verificationCancelled, .quoteNotExecutable:
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

    @Published private var phase: Phase = .starting

    private let quote: MoonPayBuyQuote
    private let paymentTitle: String
    private let service: MoonPayRampService
    private var task: Task<Void, Never>?
    private var transaction: MoonPayTransaction?

    init(quote: MoonPayBuyQuote, paymentTitle: String, service: MoonPayRampService) {
        self.quote = quote
        self.paymentTitle = paymentTitle
        self.service = service
    }

    deinit {
        task?.cancel()
    }

    func start() {
        guard task == nil else { return }
        let updates = service.pay(quote: quote)
        task = Task { [weak self] in
            for await update in updates {
                guard let self, !Task.isCancelled else { return }
                apply(update)
            }
        }
    }

    func close() {
        task?.cancel()
        onClose?()
    }

    func copy(_ value: String) {
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ToastPresenter.showToast(configuration: .copied)
    }

    func tapAction() {
        guard case let .failed(failure, _) = phase else { return }
        task?.cancel()
        onRetry?(failure.retry)
    }

    var screenState: MoonPayPaymentStatusViewState {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        let receive = amountText(quote.destination)
        return MoonPayPaymentStatusViewState(
            title: Status.title,
            steps: steps(receive: receive),
            summary: [
                .init(id: SummaryID.paid.rawValue, title: Status.youPaid, value: amountText(quote.source)),
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
            showsDetails: !isFailed,
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
        case let .stillProcessing(transaction):
            self.transaction = transaction
            phase = .stillProcessing(transaction)
        case let .failed(error):
            let started: Bool
            switch phase {
            case .started, .pending: started = true
            default: started = false
            }
            phase = .failed(Failure(error), afterStart: started)
        }
    }

    private func steps(receive: String) -> [MoonPayPaymentStatusViewState.Step] {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        let authorised = "\(paymentTitle) · \(Status.authorised(amountText(quote.source)))"
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
            completed = step(.completed, Status.completed, Status.stillProcessingSubtitle, .waiting)
        case let .failed(failure, afterStart):
            let (title, subtitle) = failureText(failure)
            if afterStart {
                started.status = .done
                pending = step(.pending, title, subtitle, .failed)
            } else {
                started = step(.started, title, subtitle, .failed)
            }
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

    private func amountText(_ money: MoonPayMoney) -> String {
        let code = (money.asset.code ?? "").uppercased()
        let amount = money.amount ?? "0"
        return code.isEmpty ? amount : "\(amount) \(code)"
    }

    private func totalFees() -> String {
        let fees = quote.fees ?? [:]
        let code = quote.source.asset.code
        let total = fees.values
            .filter { $0.asset.code == code }
            .compactMap { $0.amount.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) } }
            .reduce(Decimal(0), +)
        let text = NSDecimalNumber(decimal: total).stringValue
        return "\(text) \((code ?? "").uppercased())"
    }

    private func feeRows() -> [MoonPayPaymentStatusViewState.SummaryRow] {
        (quote.fees ?? [:]).sorted { $0.key < $1.key }.map { key, money in
            .init(id: key, title: key.prefix(1).uppercased() + key.dropFirst(), value: amountText(money))
        }
    }
}
