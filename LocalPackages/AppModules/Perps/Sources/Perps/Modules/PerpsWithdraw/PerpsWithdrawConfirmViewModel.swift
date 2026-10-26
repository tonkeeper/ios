import Combine
import Foundation
import PerpsModels
import TKLocalize
import TKLogging
import UIKit

@MainActor
final class PerpsWithdrawConfirmViewModel: PerpsTradeConfirmViewModeling {
    @Published private(set) var errorText: String?
    @Published private var reviewed: PerpsReviewedWithdraw
    @Published private var isPaying = false
    @Published private var isRequoting = false

    var isConfirmationEnabled: Bool {
        !isPaying && !isRequoting
    }

    var isProcessing: Bool {
        isPaying
    }

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var onPaid: ((String) -> Void)?

    private let destination: PerpsDepositSource
    private let balance: PerpsFundingBalance?
    private let format: PerpsFormatting
    private let message: (Error) -> PerpsWithdrawMessage
    private let passcodeProvider: () async -> String?
    /// Reviews the same amount again once the quote lapsed or its fee moved.
    private let requote: (() async throws -> PerpsReviewedWithdraw)?
    private let now: () -> Date
    private var requoteTask: Task<Void, Never>?

    init(
        reviewed: PerpsReviewedWithdraw,
        destination: PerpsDepositSource,
        balance: PerpsFundingBalance?,
        format: PerpsFormatting,
        message: @escaping (Error) -> PerpsWithdrawMessage,
        passcodeProvider: @escaping () async -> String?,
        requote: (() async throws -> PerpsReviewedWithdraw)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.reviewed = reviewed
        self.destination = destination
        self.balance = balance
        self.format = format
        self.message = message
        self.passcodeProvider = passcodeProvider
        self.requote = requote
        self.now = now
    }

    deinit {
        requoteTask?.cancel()
    }

    private var terms: PerpsWithdrawTerms {
        reviewed.terms
    }

    var titleText: String {
        "\(TKLocales.Perps.withdraw) \(terms.receiveSymbol)"
    }

    var titleSuffixText: String? {
        destination.network.displayName
    }

    var iconLetter: String {
        String(terms.receiveSymbol.prefix(1))
    }

    var iconURL: URL? {
        balance?.iconURL
    }

    var iconChainImage: UIImage? {
        destination.network.chainIcon
    }

    var rows: [PerpsTradeConfirmRow] {
        var rows = [
            PerpsTradeConfirmRow(
                id: .youWithdraw,
                title: TKLocales.Perps.Funding.youWithdraw,
                value: format.usd(terms.withdrawAmount),
                subValue: nil
            ),
            PerpsTradeConfirmRow(
                id: .youReceive,
                title: TKLocales.Perps.Confirm.youReceive,
                value: "\(terms.receivesAtLeast ? "≥ " : "")\(terms.receiveAmount) \(terms.receiveSymbol)",
                subValue: nil
            ),
            PerpsFundingConfirmRows.networkFee(
                title: terms.receivesAtLeast ? TKLocales.Perps.Confirm.fee : TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
                fee: terms.networkFee,
                symbol: terms.networkFeeSymbol,
                usd: terms.networkFeeUsd,
                format: format
            ),
        ]
        if let arrivalTime {
            rows.append(arrivalTime)
        }
        return rows
    }

    private var arrivalTime: PerpsTradeConfirmRow? {
        if terms.receivesAtLeast {
            return destination.network == .bitcoin ? nil : PerpsFundingConfirmRows.arrivalTime(minutes: 2)
        }
        return terms.withdrawalDelaySeconds.map(PerpsFundingConfirmRows.arrivalTime(seconds:))
    }

    var noticeText: String? {
        errorText ?? highFeeNotice
    }

    var isNoticeError: Bool {
        errorText != nil
    }

    var isNoticeWarning: Bool {
        errorText == nil && highFeeNotice != nil
    }

    private var highFeeNotice: String? {
        PerpsFundingConfirmRows.highFeeNotice(fee: terms.networkFeeUsd, of: PerpsFundingAmountInput.decimal(terms.withdrawAmount))
    }

    func onAppear() {}
    func onDisappear() {}
    func editAutoClose() {}

    func confirm() {
        guard isConfirmationEnabled else { return }
        if let expiresAt = terms.expiresAt, expiresAt <= now() {
            requoteOrShow(PerpsWithdrawErrorText.text(for: .quoteExpired))
            return
        }
        isPaying = true
        errorText = nil
        Task { [weak self, reviewed, message, passcodeProvider] in
            guard let passcode = await passcodeProvider() else {
                self?.isPaying = false
                return
            }
            do {
                let operationId = try await reviewed.pay(passcode)
                self?.isPaying = false
                self?.onPaid?(operationId)
            } catch {
                Log.w("🪵 Perps withdraw: payment failed", error: error)
                guard let self else { return }
                isPaying = false
                let failure = message(error)
                // Refused before anything was signed or sent, so a fresh quote is safe to pay.
                if failure == .quoteExpired {
                    requoteOrShow(PerpsWithdrawErrorText.text(for: failure))
                } else {
                    errorText = PerpsWithdrawErrorText.text(for: failure)
                }
            }
        }
    }

    /// Not while a withdrawal is under way: its outcome would land on a screen nobody sees.
    func back() {
        guard !isPaying else { return }
        onBack?()
    }

    func close() {
        guard !isPaying else { return }
        onClose?()
    }

    private func requoteOrShow(_ notice: String?) {
        guard let requote else {
            errorText = notice
            return
        }
        requoteTask?.cancel()
        isRequoting = true
        requoteTask = Task { [weak self, message] in
            do {
                let fresh = try await requote()
                guard let self, !Task.isCancelled else { return }
                reviewed = fresh
                errorText = notice
                isRequoting = false
            } catch {
                guard let self, !Task.isCancelled else { return }
                Log.w("🪵 Perps withdraw: requote failed", error: error)
                errorText = PerpsWithdrawErrorText.text(for: message(error))
                isRequoting = false
            }
        }
    }
}
