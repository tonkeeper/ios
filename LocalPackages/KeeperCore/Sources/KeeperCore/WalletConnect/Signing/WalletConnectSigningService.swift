import ChainKit
import Foundation
import OperationReviewModels
import TKLogging

public final class WalletConnectSigningService {
    /// Signs a reviewed operation from the account with the unlocked keys, at the fee or else at
    /// chain-kit's price and from the nonce or else the account's next, and broadcasts it unless
    /// `beforeBroadcast` refuses the transaction about to go out; returns its hashes.
    typealias OperationSend = (
        ChainKit.Operation,
        ChainKit.Account,
        MnemonicWallet,
        (any Fee)?,
        BignumBigInteger?,
        _ beforeBroadcast: (ChainKitSignedTransaction) async throws -> Void
    ) async throws(WalletConnectSigningError) -> [String]

    /// Signs a reviewed operation from the account with the unlocked keys, at the fee or else at
    /// chain-kit's price and from the nonce or else the account's next, and sends nothing; returns each
    /// payload's signed transaction as chain-kit writes it.
    typealias OperationSign = (
        ChainKit.Operation,
        ChainKit.Account,
        MnemonicWallet,
        (any Fee)?,
        BignumBigInteger?
    ) async throws(WalletConnectSigningError) -> [String]

    private let mnemonicAccess: MnemonicAccess
    private let client: CryptoKitClient
    private let pendingTransactionsService: PendingTransactionsService
    private let gate: OperationGate
    private let signsDappOperations: Bool
    private let sendOperation: OperationSend
    private let signOperation: OperationSign
    private let requestSigner: WalletConnectRequestSigner

    /// - Parameters:
    ///   - signsDappOperations: whether a mnemonic's EVM transaction is signed as the operation its
    ///     review reads rather than by the SDK.
    ///   - sendOperation: ``sending(through:)`` chain-kit's sender, unless a test stands in for the chain.
    ///   - signOperation: ``signing(through:)`` chain-kit's sender, unless a test stands in for it.
    init(
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        pendingTransactionsService: PendingTransactionsService,
        gate: OperationGate,
        signsDappOperations: Bool,
        sendOperation: @escaping OperationSend,
        signOperation: @escaping OperationSign
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.client = client
        self.pendingTransactionsService = pendingTransactionsService
        self.gate = gate
        self.signsDappOperations = signsDappOperations
        self.sendOperation = sendOperation
        self.signOperation = signOperation
        self.requestSigner = WalletConnectRequestSigner()
    }

    /// - Parameters:
    ///   - evmFee: the fee from ``quoteEVMFee(wallet:request:)`` the confirmation showed; without it
    ///     an EVM transaction is priced while signing.
    ///   - consent: the confirm attempt's, asked about what the review of the request finds before
    ///     the passcode or the device; a refusal is `.canceled`.
    ///   - isPending: whether the dApp still waits for the request, checked after the review and unlock,
    ///     around device signing and before broadcast. An ended request is `.canceled` before
    ///     submission and `.requestEndedAfterBroadcast` after a successful broadcast. A signature
    ///     or broadcast already in flight cannot be recalled.
    public func sign(
        signer: MultichainTransferSigner,
        wallet: Wallet,
        request: WalletConnectSessionRequest,
        evmFee: WalletConnectEVMFee?,
        consent: OperationConsent,
        isPending: @escaping @Sendable () async -> Bool
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        try await sign(.ask, consent: consent, isPending: isPending, signer: signer, wallet: wallet, request: request, evmFee: evmFee)
    }

    /// As ``sign(signer:wallet:request:evmFee:consent:isPending:)``, with what the review finds only
    /// logged: Earn asks nothing until it shows the findings, so its review never waits on the user.
    public func signWithoutAsking(
        signer: MultichainTransferSigner,
        wallet: Wallet,
        request: WalletConnectSessionRequest
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        try await sign(.logOnly, consent: .refuse, isPending: { true }, signer: signer, wallet: wallet, request: request, evmFee: nil)
    }

    /// What the confirmation tints its control by: the review of what `request` is signed as. Never asks.
    public func review(wallet: Wallet, request: WalletConnectSessionRequest) async -> OperationReview? {
        await gate.preview(.ask) {
            try WalletConnectOperationFactory.signables(of: request, wallet: wallet)
        }
    }

    /// Prices an EVM transaction request without unlocking the wallet. The fee the dApp put in the
    /// request is ignored: the wallet signs only a fee it priced and showed.
    public func quoteEVMFee(
        wallet: Wallet,
        request: WalletConnectSessionRequest
    ) async throws(WalletConnectSigningError) -> WalletConnectEVMFee {
        guard wallet.isMultichainDappsAvailable else {
            throw .unsupportedWalletKind
        }
        guard case let .evmTransaction(transaction, _) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) has no EVM transaction to price")
        }
        return try await WalletConnectEVMTransactionSigningUtilities().quoteFee(
            transaction: transaction,
            chain: request.chain,
            wallet: wallet,
            client: client
        )
    }
}

extension WalletConnectSigningService {
    /// Sends through `sender` at the fee shown, or at chain-kit's price read just before when none was.
    /// A dApp's transaction has no quote to expire, and nothing of it is kept to resume.
    static func sending(through sender: ChainKitOperationSender) -> OperationSend {
        { operation, account, wallet, shownFee, nonce, beforeBroadcast async throws(WalletConnectSigningError) -> [String] in
            let fee = if let shownFee { shownFee } else { try await price(operation, account: account, client: sender.client) }
            do {
                return try await sender.send(
                    operation,
                    account: account,
                    wallet: wallet,
                    expiresAt: .distantFuture,
                    fees: [fee],
                    startingNonce: nonce,
                    persist: { transaction in
                        // The sender keeps a transaction as attempted right before it goes out.
                        if transaction.broadcastAttempted, !transaction.acknowledged {
                            try await beforeBroadcast(transaction)
                        }
                    }
                )
            } catch {
                Log.walletConnect.w("evm operation send failed", error: error)
                throw failure(of: error)
            }
        }
    }

    /// Signs through `sender` at the fee shown, or at chain-kit's price read just before when none was.
    static func signing(through sender: ChainKitOperationSender) -> OperationSign {
        { operation, account, wallet, shownFee, nonce async throws(WalletConnectSigningError) -> [String] in
            let fee = if let shownFee { shownFee } else { try await price(operation, account: account, client: sender.client) }
            do {
                return try await sender.sign(operation, account: account, wallet: wallet, fees: [fee], startingNonce: nonce).map(\.data)
            } catch {
                Log.walletConnect.w("evm operation signing failed", error: error)
                throw failure(of: error)
            }
        }
    }

    /// A failed send as the request's signer names it: the request's own refusal as it is, the user's
    /// cancellation only for a cancelled task, the failure of its step otherwise.
    static func failure(of error: any Error) -> WalletConnectSigningError {
        switch error {
        case let error as WalletConnectSigningError:
            error
        case is CancellationError:
            .canceled
        case let ChainKitOperationError.nonceUnavailable(reason, _):
            .failedToEstimateNonce(reason: reason)
        case let ChainKitOperationError.feeUnavailable(_, reason):
            .failedToCalculateFee(reason: reason)
        case let ChainKitOperationError.signingFailed(_, reason, _):
            .failedToSign(reason: reason)
        case ChainKitOperationError.insufficientFunds:
            .failedToSend(reason: "the node refused the transaction for want of funds")
        case let ChainKitOperationError.broadcastFailed(_, _, reason, _):
            .failedToSend(reason: reason)
        default:
            .failedToSign(reason: error.logDescription)
        }
    }

    /// chain-kit's price for the operation's payload, failing as the SDK's price of a dApp's transaction
    /// fails, a shortfall the node finds included.
    private static func price(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        client: CryptoKitClient
    ) async throws(WalletConnectSigningError) -> any Fee {
        guard let payload = operation.payloads.first else {
            throw .failedToCalculateFee(reason: "the operation has no payload to price")
        }
        let result: ChainRes<Fee>
        do {
            result = try await client.blockchain.getMediator(network: account.chain.network.type).operation.calculateFee(
                payload: payload,
                account: account,
                priority: .standard
            )
        } catch {
            throw .failedToCalculateFee(reason: "chainkit failed to calculate fee: \(error.logDescription)")
        }
        guard let fee = result.getOrNull() else {
            throw .failedToCalculateFee(reason: "chainkit failed to calculate fee: \(result.error.map { "\($0)" } ?? "unknown")")
        }
        return fee
    }
}

private extension WalletConnectSigningService {
    /// The gate clears the request before its signer asks for the passcode or the device, so a
    /// refusal unlocks nothing.
    func sign(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        isPending: @escaping @Sendable () async -> Bool,
        signer: MultichainTransferSigner,
        wallet: Wallet,
        request: WalletConnectSessionRequest,
        evmFee: WalletConnectEVMFee?,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        switch (wallet.kind, signer) {
        case (.regular, .mnemonic), (.ledger, .device):
            break
        default:
            throw .unsupportedWalletKind
        }
        let context = WalletConnectSigningContext(
            signer: signer,
            wallet: wallet,
            mnemonicAccess: mnemonicAccess,
            client: client,
            pendingTransactionsService: pendingTransactionsService,
            evmFee: evmFee,
            isPending: isPending
        )
        if case .mnemonic = signer, case let .evmTransaction(transaction, send) = request.payload,
           request.chain.eip155ChainId != nil, signsDappOperations
        {
            return try await signReviewedOperation(
                presentation,
                consent: consent,
                of: transaction,
                send: send,
                request: request,
                context: context,
                file: file,
                function: function,
                line: line
            )
        }
        if case .mnemonic = signer, case let .signMessage(message) = request.payload, case .tron = message.kind, signsDappOperations {
            return try await signReviewedTronMessage(
                presentation,
                consent: consent,
                message: message,
                request: request,
                context: context,
                file: file,
                function: function,
                line: line
            )
        }
        // A payload the factory refuses is the dApp's error, as it is with no checks or on the
        // operation path, not a review that read nothing.
        var refused: WalletConnectSigningError?
        do throws(WalletConnectSigningError) {
            try await clear(presentation, consent: consent, file: file, function: function, line: line) {
                do {
                    return try WalletConnectOperationFactory.signables(of: request, wallet: wallet)
                } catch let error as WalletConnectSigningError {
                    refused = error
                    throw error
                }
            }
        } catch {
            guard case .unreviewable = error, let refused else {
                throw error
            }
            throw refused
        }
        return try await requestSigner.sign(request: request, context: context)
    }

    /// The dApp's sender, nonce and call are read before the gate, which clears the very operation then
    /// signed from the unlocked keys: at the fee shown, or chain-kit's price without one, and at the
    /// dApp's nonce, or the account's next without one. A transaction the dApp only wants signed is
    /// answered with its signed bytes and goes nowhere. One to send is sent and recorded in a task the
    /// cancellation of the request's task does not reach once the unlock released it, so only the
    /// request's end stops it, and only before its broadcast, as it stops the SDK's.
    func signReviewedOperation(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        of transaction: WalletConnectEVMTransaction,
        send: Bool,
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        let sender = try context.accountAddress(chain: request.chain)
        if let from = transaction.from, !from.isEmpty {
            try context.validateSameAddress(expected: sender, actual: from, chain: request.chain)
        }
        let nonce = try transaction.optionalEVMQuantity(.nonce).map(WalletConnectEVMTransactionSigningUtilities().bignum)
        let signable: SignableOperation
        do {
            signable = try WalletConnectOperationFactory.evmTransaction(transaction, of: request, wallet: context.wallet, fidelity: .exact)
        } catch let error as WalletConnectSigningError {
            throw error
        } catch {
            throw .unreviewable(reason: "the transaction could not be read as an operation: \(error.logDescription)")
        }
        try await clear(presentation, consent: consent, file: file, function: function, line: line) { [signable] }
        let unlocked = try await context.cryptoWallet()
        let account: ChainKit.Account
        do {
            account = try ChainKitOperationSender.account(signable.account, signedBy: unlocked)
        } catch {
            throw .failedToSign(reason: "the reviewed operation is not the unlocked wallet's to sign: \(error.logDescription)")
        }
        let fee = context.evmFee?.chainKitFee(chain: request.chain)
        guard send else {
            let signed = try await signOperation(signable.operation, account, unlocked, fee, nonce)
            guard let transaction = signed.last else {
                throw .failedToSign(reason: "the operation was signed as no transaction")
            }
            try await context.checkRequestIsPending()
            return .string(transaction)
        }
        let sending = Task { [sendOperation] () async -> Result<String, WalletConnectSigningError> in
            do throws(WalletConnectSigningError) {
                let hashes = try await sendOperation(signable.operation, account, unlocked, fee, nonce) { _ in
                    try await context.checkRequestIsPending()
                }
                guard let hash = hashes.last else {
                    throw .failedToSend(reason: "the operation was sent as no transaction")
                }
                await context.reportPendingTransaction(chain: request.chain, txHash: hash, activityType: transaction.pendingActivityType)
                return .success(hash)
            } catch {
                return .failure(error)
            }
        }
        let hash = try await sending.value.get()
        try await context.checkRequestIsPending()
        return .string(hash)
    }

    /// The address the dApp names is read before the gate, which clears the very message then signed by
    /// chain-kit from the unlocked keys, TIP-191 as the SDK's signer signs it; the dApp gets its signature.
    func signReviewedTronMessage(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        message: WalletConnectSignMessage,
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        try context.validateAddress(message.address, chain: request.chain)
        let signable: SignableOperation
        do {
            signable = try WalletConnectOperationFactory.tronMessage(message.message, of: request, wallet: context.wallet, fidelity: .exact)
        } catch {
            throw .unreviewable(reason: "the message could not be read as an operation: \(error.logDescription)")
        }
        try await clear(presentation, consent: consent, file: file, function: function, line: line) { [signable] }
        let unlocked = try await context.cryptoWallet()
        let signature: String
        do {
            guard let payload = signable.operation.payloads.first else {
                throw ChainKitOperationError.malformed(signable.operation.id)
            }
            let account = try ChainKitOperationSender.account(signable.account, signedBy: unlocked)
            signature = try await ChainKitOperationSender(client: client).signMessage(payload, account: account, wallet: unlocked)
        } catch {
            try await context.checkRequestIsPending()
            Log.walletConnect.w("tron message signing failed", error: error)
            throw Self.failure(of: error)
        }
        try await context.checkRequestIsPending()
        return .object(["signature": signature])
    }

    /// A refusal fails the request: a decline as the user's cancellation, an operation the review could
    /// not read or check as unreviewable.
    func clear(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        file: StaticString,
        function: StaticString,
        line: UInt,
        _ build: () async throws -> [SignableOperation]
    ) async throws(WalletConnectSigningError) {
        do throws(OperationRefusal) {
            try await gate.clear(presentation, consent: consent, file: file, function: function, line: line, build)
        } catch {
            switch error {
            case .declined:
                throw .canceled
            case let .unreviewable(reason):
                throw .unreviewable(reason: reason)
            }
        }
    }
}
