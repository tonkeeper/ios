import ChainKit

/// Type-erases ChainKit's generic mediators so the swap pipeline can be exercised
/// as a state machine without network, signing, or KMP runtime side effects.
protocol SwapPipelineStageProvider {
    func resolveFee(
        transactions: [TransactionSwap],
        payloadFee: (any Fee)?,
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee

    func defaultFee(
        transactions: [TransactionSwap],
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee

    func reserve(
        transactions: [TransactionSwap],
        feeAsset: AssetCoin,
        fee: any Fee,
        policy: GasReservePolicy,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult

    func buildApproval(
        mainTransactions: [TransactionSwap],
        approvalData: String?,
        approvalFee: (any Fee)?,
        mainFee: any Fee,
        approvalMode: MultichainSwapApprovalMode
    ) -> SwapApprovalTransaction?

    func nonce(
        account: ChainKit.Account,
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> BignumBigInteger

    func unlockSigningWallet(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> SwapSigningWallet

    func signAndBroadcast(
        transactions: [any ChainKit.Transaction],
        fee: any Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        networkType: ChainKit.Network.Type_,
        wallet: SwapSigningWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> String
}

final class SwapPipelineStageProviderImplementation: SwapPipelineStageProvider {
    private let client: CryptoKitClient
    private let walletUnlocker: SwapWalletUnlocker
    private let gasReserveResolver: SwapGasReserveResolver
    private let approvalResolver: SwapApprovalTransactionResolver
    private let feeResolver = SwapFeeResolver()
    private let nonceProvider = SwapNonceProvider()
    private let transactionSigner = SwapTransactionSigner()
    private let transactionBroadcaster = SignedSwapTransactionBroadcaster()

    init(mnemonicAccess: MnemonicAccess, client: CryptoKitClient) {
        self.client = client
        walletUnlocker = SwapWalletUnlocker(mnemonicAccess: mnemonicAccess)
        gasReserveResolver = SwapGasReserveResolver(client: client)
        approvalResolver = SwapApprovalTransactionResolver(client: client)
    }

    func resolveFee(
        transactions: [TransactionSwap],
        payloadFee: (any Fee)?,
        networkType: ChainKit.Network.Type_,
        payloadId _: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        if let payloadFee {
            return payloadFee
        }
        do {
            return try await feeResolver.resolveFee(
                mediator: client.blockchain.getMediator(network: networkType),
                batch: transactions
            )
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    func defaultFee(
        transactions: [TransactionSwap],
        networkType: ChainKit.Network.Type_,
        payloadId _: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        do {
            return try await feeResolver.resolveDefaultFee(
                mediator: client.blockchain.getMediator(network: networkType),
                batch: transactions
            )
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    func reserve(
        transactions: [TransactionSwap],
        feeAsset: AssetCoin,
        fee: any Fee,
        policy: GasReservePolicy,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult {
        try await gasReserveResolver.reserve(
            for: transactions,
            feeAsset: feeAsset,
            fee: fee,
            policy: policy,
            payloadId: payloadId
        )
    }

    func buildApproval(
        mainTransactions: [TransactionSwap],
        approvalData: String?,
        approvalFee: (any Fee)?,
        mainFee: any Fee,
        approvalMode: MultichainSwapApprovalMode
    ) -> SwapApprovalTransaction? {
        approvalResolver.resolveApprovalTransaction(
            mainTransactions: mainTransactions,
            approvalData: approvalData,
            approvalFee: approvalFee,
            mainFee: mainFee,
            approvalMode: approvalMode
        )
    }

    func nonce(
        account: ChainKit.Account,
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> BignumBigInteger {
        try await nonceProvider.nonce(
            mediator: client.blockchain.getMediator(network: networkType),
            account: account,
            payloadId: payloadId
        )
    }

    func unlockSigningWallet(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> SwapSigningWallet {
        try await walletUnlocker.unlockSigningWallet(
            passcodeProvider: passcodeProvider,
            swapWallet: swapWallet
        )
    }

    func signAndBroadcast(
        transactions: [any ChainKit.Transaction],
        fee: any Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        networkType: ChainKit.Network.Type_,
        wallet: SwapSigningWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> String {
        guard let account = transactions.first?.account else {
            throw .signingFailed(
                payloadId: payloadId,
                kind: .missingField,
                reason: "swap payload has no transaction to sign"
            )
        }
        let mediator = client.blockchain.getMediator(network: networkType)
        let signingOutput = try await transactionSigner.signAndEncode(
            mediator: mediator,
            transactions: transactions,
            fee: fee,
            nonce: nonce,
            sourceChain: sourceChain,
            wallet: wallet,
            payloadId: payloadId
        )
        return try await transactionBroadcaster.broadcast(
            mediator: mediator,
            account: account,
            signingOutput: signingOutput,
            payloadId: payloadId
        )
    }
}
