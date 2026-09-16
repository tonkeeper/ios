import ChainKit

/// Type-erases ChainKit's generic mediators so the swap pipeline can be exercised
/// as a state machine without network, signing, or KMP runtime side effects.
protocol SwapPipelineStageProvider {
    func resolveFee(
        transaction: any ChainKit.Transaction,
        payloadFee: (any Fee)?,
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee

    func defaultFee(
        transaction: any ChainKit.Transaction,
        networkType: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee

    func reserve(
        transaction: TransactionSwap,
        feeAsset: AssetCoin,
        fee: any Fee,
        policy: GasReservePolicy,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult

    func buildApproval(
        mainTransaction: TransactionSwap,
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
        wallet: Wallet
    ) async throws(MultichainSwapExecutionFailure) -> CryptoWallet

    func signAndBroadcast(
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        networkType: ChainKit.Network.Type_,
        wallet: CryptoWallet,
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
        transaction: any ChainKit.Transaction,
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
                transaction: transaction
            )
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    func defaultFee(
        transaction: any ChainKit.Transaction,
        networkType: ChainKit.Network.Type_,
        payloadId _: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        do {
            return try await feeResolver.resolveDefaultFee(
                mediator: client.blockchain.getMediator(network: networkType),
                transaction: transaction
            )
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    func reserve(
        transaction: TransactionSwap,
        feeAsset: AssetCoin,
        fee: any Fee,
        policy: GasReservePolicy,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult {
        try await gasReserveResolver.reserve(
            for: transaction,
            feeAsset: feeAsset,
            fee: fee,
            policy: policy,
            payloadId: payloadId
        )
    }

    func buildApproval(
        mainTransaction: TransactionSwap,
        approvalData: String?,
        approvalFee: (any Fee)?,
        mainFee: any Fee,
        approvalMode: MultichainSwapApprovalMode
    ) -> SwapApprovalTransaction? {
        approvalResolver.resolveApprovalTransaction(
            mainTransaction: mainTransaction,
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
        wallet: Wallet
    ) async throws(MultichainSwapExecutionFailure) -> CryptoWallet {
        try await walletUnlocker.unlockSigningWallet(
            passcodeProvider: passcodeProvider,
            wallet: wallet
        )
    }

    func signAndBroadcast(
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        sourceChain: MultichainChain,
        networkType: ChainKit.Network.Type_,
        wallet: CryptoWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> String {
        let mediator = client.blockchain.getMediator(network: networkType)
        let signingOutput = try await transactionSigner.signAndEncode(
            mediator: mediator,
            transaction: transaction,
            fee: fee,
            nonce: nonce,
            sourceChain: sourceChain,
            wallet: wallet,
            payloadId: payloadId
        )
        return try await transactionBroadcaster.broadcast(
            mediator: mediator,
            account: transaction.account,
            signingOutput: signingOutput,
            payloadId: payloadId
        )
    }
}
