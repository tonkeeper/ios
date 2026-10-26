import Foundation
import KeeperCore
import TKCore
import TKLogging

@MainActor
struct EarnDappAnalytics {
    let analyticsProvider: AnalyticsProvider
    let from: DappAppFrom
    let utm: UtmParameters
    let dappUrl: String?

    func logSigning(_ event: EarnSigningEvent) {
        guard let method = EarnSignMethod(event.method),
              let chain = DappBrowserAnalyticsController.assetChain(from: event.chain.multichainChain)
        else {
            return
        }
        let vaultId = event.pageURL?.earnVaultAssetId
        switch event.stage {
        case .requested:
            log(EarnSignRequest(from: from, method: method, chain: chain, vaultId: vaultId))
        case .signed:
            log(EarnSignSuccess(from: from, method: method, chain: chain, vaultId: vaultId))
        case .rejected:
            log(EarnSignRejected(from: from, method: method, chain: chain, vaultId: vaultId))
        case let .failed(failure):
            log(
                EarnSignFailed(
                    from: from,
                    method: method,
                    chain: chain,
                    vaultId: vaultId,
                    errorCode: failure.code,
                    errorMessage: failure.reason?.redactingLongHex
                )
            )
        }
    }

    func logTransactionSent(wallet: Wallet, chain: WalletConnectChain, transaction: WalletConnectEVMTransaction) {
        guard let assetChain = DappBrowserAnalyticsController.assetChain(from: chain.multichainChain),
              let event = TransactionSent(
                  wallet: wallet,
                  evmTransaction: transaction,
                  chain: assetChain,
                  origin: TransactionOrigin(initiatedBy: .evmInjected, dappUrl: dappUrl, utm: utm)
              )
        else {
            return
        }
        log(event)
    }

    func logClose(exitMethod: EarnExitMethod, durationMs: Int64) {
        log(EarnClose(from: from, exitMethod: exitMethod, durationMs: durationMs))
    }

    func logPageEvent(name: String, params: [String: Any]) {
        let params = params.merging(Self.pageEventOrigin) { _, origin in origin }
        do {
            if let event = try Self.pageEvent(named: name, params: params) {
                log(event)
                return
            }
            Log.e("earn page event is not in the schema", extraInfo: ["event": name])
        } catch {
            Log.e("earn page event does not match the schema", extraInfo: ["event": name, "error": "\(error)"])
        }
        let redacted = params.mapValues { value -> Any in
            guard let text = value as? String else { return value }
            let redactedText = text.redactingLongHex
            return redactedText == text || MultichainChain(assetId: text) != nil ? text : redactedText
        }
        analyticsProvider.log(event: .Dapp.track(event: name, params: redacted), utm: utm)
    }

    private func log(_ event: Encodable) {
        analyticsProvider.log(event, utm: utm)
    }
}

private extension EarnDappAnalytics {
    enum PageEventError: Error {
        case notJSON
    }

    static var pageEventOrigin: [String: Any] {
        ["isExternalWebView": 1, "eventProvider": "vaults.fyi"]
    }

    static func pageEvent(named name: String, params: [String: Any]) throws -> (any Encodable)? {
        var payload = params
        for key in ["error_message", "url"] {
            if let value = payload[key] as? String {
                payload[key] = value.redactingLongHex
            }
        }
        payload["eventName"] = name
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw PageEventError.notJSON
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        switch name {
        case "earn_webview_screen_view":
            return try decoder.decode(EarnWebviewScreenView.self, from: data)
        case "earn_vault_list_viewed":
            return try decoder.decode(EarnVaultListViewed.self, from: data)
        case "earn_vault_filter_applied":
            return try decoder.decode(EarnVaultFilterApplied.self, from: data)
        case "earn_vault_sort_applied":
            return try decoder.decode(EarnVaultSortApplied.self, from: data)
        case "earn_vault_selected":
            return try decoder.decode(EarnVaultSelected.self, from: data)
        case "earn_deposit_started":
            return try decoder.decode(EarnDepositStarted.self, from: data)
        case "earn_deposit_amount_entered":
            return try decoder.decode(EarnDepositAmountEntered.self, from: data)
        case "earn_deposit_review_shown":
            return try decoder.decode(EarnDepositReviewShown.self, from: data)
        case "earn_deposit_confirm_tapped":
            return try decoder.decode(EarnDepositConfirmTapped.self, from: data)
        case "earn_deposit_success":
            return try decoder.decode(EarnDepositSuccess.self, from: data)
        case "earn_deposit_failed":
            return try decoder.decode(EarnDepositFailed.self, from: data)
        case "earn_withdraw_started":
            return try decoder.decode(EarnWithdrawStarted.self, from: data)
        case "earn_withdraw_amount_entered":
            return try decoder.decode(EarnWithdrawAmountEntered.self, from: data)
        case "earn_withdraw_review_shown":
            return try decoder.decode(EarnWithdrawReviewShown.self, from: data)
        case "earn_withdraw_confirm_tapped":
            return try decoder.decode(EarnWithdrawConfirmTapped.self, from: data)
        case "earn_withdraw_requested":
            return try decoder.decode(EarnWithdrawRequested.self, from: data)
        case "earn_withdraw_success":
            return try decoder.decode(EarnWithdrawSuccess.self, from: data)
        case "earn_withdraw_failed":
            return try decoder.decode(EarnWithdrawFailed.self, from: data)
        case "earn_claim_started":
            return try decoder.decode(EarnClaimStarted.self, from: data)
        case "earn_claim_success":
            return try decoder.decode(EarnClaimSuccess.self, from: data)
        case "earn_claim_failed":
            return try decoder.decode(EarnClaimFailed.self, from: data)
        case "earn_position_viewed":
            return try decoder.decode(EarnPositionViewed.self, from: data)
        case "earn_history_viewed":
            return try decoder.decode(EarnHistoryViewed.self, from: data)
        case "earn_external_link_clicked":
            return try decoder.decode(EarnExternalLinkClicked.self, from: data)
        case "earn_webview_error":
            return try decoder.decode(EarnWebviewError.self, from: data)
        default:
            return nil
        }
    }
}

private extension EarnSignMethod {
    init?(_ method: WalletConnectMethod) {
        switch method {
        case .ethSendTransaction:
            self = .sendTransaction
        case .personalSign:
            self = .personalSign
        case .ethSignTypedDataV4:
            self = .signTypedData
        case .ethSignTransaction, .walletSwitchEthereumChain, .walletGetCapabilities,
             .tronSignMessage, .tronSignTransaction, .tonSendMessage, .tonSignData,
             .solanaGetAccounts, .solanaRequestAccounts, .solanaSignMessage, .solanaSignTransaction,
             .solanaSignAndSendTransaction, .solanaSignAllTransactions:
            return nil
        }
    }
}

private extension EarnSigningFailure {
    var code: String {
        switch self {
        case .noAccount:
            "no_account"
        case let .invalidRequest(error):
            error.analyticsCode
        case let .signer(error):
            error.analyticsCode
        case .unexpectedResponse:
            "unexpected_response"
        }
    }

    var reason: String? {
        switch self {
        case let .invalidRequest(error):
            error.reason
        case let .signer(error):
            error.reason
        case .noAccount, .unexpectedResponse:
            nil
        }
    }
}

private extension WalletConnectRequestParsingError {
    var analyticsCode: String {
        switch self {
        case .unsupportedMethod:
            "unsupported_method"
        case .unsupportedChain:
            "unsupported_chain"
        case .invalidParams:
            "invalid_params"
        case .chainMismatch:
            "chain_mismatch"
        }
    }

    var reason: String? {
        guard case let .invalidParams(_, reason) = self else { return nil }
        return reason
    }
}

private extension WalletConnectSigningError {
    var analyticsCode: String {
        switch self {
        case .canceled:
            "canceled"
        case .unsupportedWalletKind:
            "unsupported_wallet_kind"
        case .missingMultichainAddress:
            "missing_multichain_address"
        case .senderAddressMismatch:
            "sender_address_mismatch"
        case .missingRecipient:
            "missing_recipient"
        case .missingPasscode:
            "missing_passcode"
        case .mnemonic:
            "mnemonic"
        case .invalidPayload:
            "invalid_payload"
        case .invalidTransaction:
            "invalid_transaction"
        case .failedToEstimateNonce:
            "failed_to_estimate_nonce"
        case .failedToCalculateFee:
            "failed_to_calculate_fee"
        case .failedToSign:
            "failed_to_sign"
        case .failedToSend:
            "failed_to_send"
        case .notImplemented:
            "not_implemented"
        }
    }

    var reason: String? {
        switch self {
        case let .mnemonic(reason),
             let .invalidPayload(reason),
             let .invalidTransaction(reason),
             let .failedToEstimateNonce(reason),
             let .failedToCalculateFee(reason),
             let .failedToSign(reason),
             let .failedToSend(reason),
             let .notImplemented(reason):
            reason
        case .canceled, .unsupportedWalletKind, .missingMultichainAddress, .senderAddressMismatch,
             .missingRecipient, .missingPasscode:
            nil
        }
    }
}

private extension String {
    var redactingLongHex: String {
        replacingOccurrences(of: "(0x)?[0-9a-fA-F]{40,}", with: "<hex>", options: .regularExpression)
    }
}
