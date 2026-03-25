//
//  TONWalletKitSignRawResultHandler.swift
//  WalletCore
//
//  Created by Nikita Rodionov on 16.02.2026.
//

import Foundation
import TONWalletKit

public struct TONWalletKitSignRawResultHandler: SignRawControllerResultHandler {
    public var didCancelHandler: (() -> Void)?

    private let transactionRequest: TONWalletSendTransactionRequest
    private let app: TonConnectApp

    public init(
        transactionRequest: TONWalletSendTransactionRequest,
        app: TonConnectApp
    ) {
        self.transactionRequest = transactionRequest
        self.app = app
    }

    public func didConfirm(boc: String) {
        Task {
            do {
                let response = try TONSendTransactionApprovalResponse(
                    signedBoc: TONBase64(base64Encoded: boc)
                )
                try await transactionRequest.approve(response: response)
            } catch {
                print("Log: Failed to approve sign transaction: \(error)")
            }
        }
    }

    public func didFail(error: SomeOf<TransferError, TransactionConfirmationError>) {
        Task {
            try? await transactionRequest.reject(reason: error.localizedDescription)
        }
    }

    public func didCancel() {
        didCancelHandler?()
        Task {
            try? await transactionRequest.reject()
        }
    }
}
