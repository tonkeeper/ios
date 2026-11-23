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
    private var requoteTask: Task<Void, Never>?

    init(
        reviewed: PerpsReviewedWithdraw,
        destination: PerpsDepositSource,
        balance: PerpsFundingBalance?,
        format: PerpsFormatting,
        message: @escaping (Error) -> PerpsWithdrawMessage,
        passcodeProvider: @escaping () async -> String?,
        requote: (() async throws -> PerpsReviewedWithdraw)? = nil
    ) {
        self.reviewed = reviewed
        self.destination = destination
        self.balance = balance
        self.format = format
        self.message = message
        self.passcodeProvider = passcodeProvider
        self.requote = requote
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
                value: (terms.receivesAtLeast ? "≥ " : "") + receiveText,
                subValue: nil
            ),
        ]
        if let recipientAddress = terms.recipientAddress {
            rows.append(PerpsTradeConfirmRow(
                id: .recipientAddress,
                title: TKLocales.ConfirmSend.Recipient.address,
                value: recipientAddress,
                subValue: nil
            ))
        }
        if let provider = terms.provider {
            rows.append(PerpsTradeConfirmRow(
                id: .provider,
                title: TKLocales.NativeSwap.Screen.Confirm.Field.provider,
                value: provider,
                subValue: nil
            ))
        }
        rows.append(PerpsFundingConfirmRows.networkFee(
            title: terms.receivesAtLeast ? TKLocales.Perps.Confirm.fee : TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee,
            fee: terms.networkFee,
            symbol: terms.networkFeeSymbol,
            usd: terms.networkFeeUsd,
            format: format
        ))
        if let arrivalTime {
            rows.append(arrivalTime)
        }
        return rows
    }

    private var receiveText: String {
        PerpsFundingAmountInput.decimal(terms.receiveAmount).map { format.tokenCompact($0, symbol: terms.receiveSymbol) }
            ?? "\(terms.receiveAmount) \(terms.receiveSymbol)"
    }

    private var arrivalTime: PerpsTradeConfirmRow? {
        return terms.estimatedDurationSeconds.map { PerpsFundingConfirmRows.arrivalTime(seconds: $0) }
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

    /// A quote lapsed by now is renewed by the payment itself, after the passcode.
    func confirm() {
        guard isConfirmationEnabled else { return }
        isPaying = true
        errorText = nil
        Task { [weak self, destination, reviewed, message, passcodeProvider] in
            guard let passcode = await passcodeProvider() else {
                PerpsOperationLog.event("unlock", outcome: "cancelled", source: "user", fields: ["flow": "withdraw", "asset_id": destination.assetId])
                self?.isPaying = false
                return
            }
            do {
                let operationId = try await reviewed.pay(passcode)
                self?.isPaying = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self?.onPaid?(operationId)
            } catch {
                PerpsOperationLog.event("confirm", outcome: "failed", error: error, fields: ["flow": "withdraw", "asset_id": destination.assetId])
                guard let self else { return }
                isPaying = false
                let failure = message(error)
                // Refused before anything was signed or sent, so a fresh quote is safe to pay.
                if failure == .quoteExpired {
                    requoteOrShow(PerpsWithdrawErrorText.text(for: failure))
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
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
                PerpsOperationLog.event("requote", outcome: "failed", error: error, fields: ["flow": "withdraw", "asset_id": destination.assetId])
                errorText = PerpsWithdrawErrorText.text(for: message(error))
                isRequoting = false
            }
        }
    }
}
