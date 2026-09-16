import BigInt
import Foundation
import TonSwift
import TronSwift
import TronSwiftAPI

public enum WalletMigrationExecutionError: Error {
    case emptyTransactions
    case unsupportedWalletKind
    case signingFailed
    case sendFailed(message: String)
    case partiallySent(message: String)
    case tronAddressUnavailable
    case insufficientTronFee
    case inactiveTronAccount

    public var hasSentTransactions: Bool {
        if case .partiallySent = self {
            return true
        }
        return false
    }
}

public protocol WalletMigrationExecutionService {
    /// `batterySendProof` is asked per BOC because the proof binds the message it travels with.
    func executeMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationPrepareResult,
        feeMethod: WalletMigrationPrepareResult.FeeMethod,
        signer: WalletTransferSigner,
        batterySendProof: (String) -> String?
    ) async throws(WalletMigrationExecutionError)

    func executeTronUSDTMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationTronPrepareResult,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID
    ) async throws(WalletMigrationExecutionError)

    /// After a successful USDT leg, a leftover TRX sweep that cannot cover its own burn may be
    /// skipped instead of failing the whole migration.
    func executeTronTRXMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationTronPrepareResult,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID,
        allowSkipInsufficient: Bool
    ) async throws(WalletMigrationExecutionError)
}

final class WalletMigrationExecutionServiceImplementation: WalletMigrationExecutionService {
    private let sendService: SendService
    private let batteryService: BatteryService
    private let tronUsdtApi: TronUSDTAPI
    private let configuration: Configuration
    private let seqnoWaiter: WalletMigrationSeqnoWaiter
    private let batteryIdleWaiter: WalletMigrationBatteryIdleWaiter
    private let tronConfirmationWaiter: WalletMigrationTronConfirmationWaiter

    init(
        sendService: SendService,
        batteryService: BatteryService,
        tronUsdtApi: TronUSDTAPI,
        configuration: Configuration
    ) {
        self.sendService = sendService
        self.batteryService = batteryService
        self.tronUsdtApi = tronUsdtApi
        self.configuration = configuration
        self.seqnoWaiter = WalletMigrationSeqnoWaiter(sendService: sendService)
        self.batteryIdleWaiter = WalletMigrationBatteryIdleWaiter(batteryService: batteryService)
        self.tronConfirmationWaiter = WalletMigrationTronConfirmationWaiter(
            loadInfo: { txId in
                try await tronUsdtApi.getTransactionInfo(txId: txId)
            }
        )
    }

    func executeMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationPrepareResult,
        feeMethod: WalletMigrationPrepareResult.FeeMethod,
        signer: WalletTransferSigner,
        batterySendProof: (String) -> String?
    ) async throws(WalletMigrationExecutionError) {
        guard sourceWallet.kind == .regular else {
            throw WalletMigrationExecutionError.unsupportedWalletKind
        }

        let transactions = prepareResult.transactionsForExecution(feeMethod: feeMethod)
        guard !transactions.isEmpty else {
            throw WalletMigrationExecutionError.emptyTransactions
        }

        switch feeMethod {
        case .ton:
            break
        case .battery:
            guard prepareResult.batteryTransactions != nil,
                  transactions.contains(where: \.sponsored)
            else {
                throw WalletMigrationExecutionError.sendFailed(
                    message: "Battery migration requires sponsored transactions from gas_payer=battery prepare"
                )
            }
        }

        let signedTransactions: [(WalletMigrationPreparedTransaction, String)]
        do {
            signedTransactions = try transactions.map { transaction in
                let signedBOC = try WalletMigrationTransactionSigner.signAndBuildExternalMessageBOC(
                    transaction: transaction,
                    wallet: sourceWallet,
                    signer: signer
                )
                return (transaction, signedBOC)
            }
        } catch {
            throw WalletMigrationExecutionError.signingFailed
        }

        let trackingHeaders = WalletMigrationTrackingHeaders.make(fee: feeMethod.trackingFee)
        var sentCount = 0
        for (index, signedTransaction) in signedTransactions.enumerated() {
            let (transaction, signedBOC) = signedTransaction
            do {
                switch feeMethod {
                case .ton:
                    try await sendService.sendTransaction(
                        boc: signedBOC,
                        wallet: sourceWallet,
                        headers: trackingHeaders
                    )
                case .battery:
                    if transaction.sponsored {
                        try await waitUntilBatteryIdle(wallet: sourceWallet)
                        try await batteryService.sendTransaction(
                            wallet: sourceWallet,
                            boc: signedBOC,
                            proof: batterySendProof(signedBOC),
                            headers: trackingHeaders
                        )
                    } else {
                        try await sendService.sendTransaction(
                            boc: signedBOC,
                            wallet: sourceWallet,
                            headers: trackingHeaders
                        )
                    }
                }
                sentCount += 1

                let isLast = index == signedTransactions.count - 1
                if !isLast {
                    try await waitUntilSeqno(
                        wallet: sourceWallet,
                        minimum: UInt64(transaction.seqno) + 1
                    )
                    if feeMethod.isBattery, transaction.sponsored {
                        try await waitUntilBatteryIdle(wallet: sourceWallet)
                    }
                }
            } catch {
                if sentCount > 0 {
                    if let error = error as? WalletMigrationExecutionError {
                        switch error {
                        case let .sendFailed(message), let .partiallySent(message):
                            throw WalletMigrationExecutionError.partiallySent(message: message)
                        default:
                            throw WalletMigrationExecutionError.partiallySent(
                                message: error.localizedDescription
                            )
                        }
                    }
                    throw WalletMigrationExecutionError.partiallySent(
                        message: WalletMigrationError.sendFailureMessage(from: error)
                    )
                }
                if let error = error as? WalletMigrationExecutionError {
                    throw error
                }
                throw WalletMigrationExecutionError.sendFailed(
                    message: WalletMigrationError.sendFailureMessage(from: error)
                )
            }
        }
    }

    private func waitUntilSeqno(wallet: Wallet, minimum: UInt64) async throws {
        guard try await seqnoWaiter.wait(wallet: wallet, minimum: minimum) else {
            throw WalletMigrationExecutionError.sendFailed(
                message: "Timed out waiting for wallet seqno \(minimum)"
            )
        }
    }

    private func waitUntilBatteryIdle(wallet: Wallet) async throws {
        guard try await batteryIdleWaiter.wait(wallet: wallet) else {
            throw WalletMigrationExecutionError.sendFailed(
                message: "Timed out waiting for battery pending_transactions to clear"
            )
        }
    }

    func executeTronUSDTMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationTronPrepareResult,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID
    ) async throws(WalletMigrationExecutionError) {
        guard prepareResult.hasUSDT else { return }

        guard sourceWallet.kind == .regular else {
            throw WalletMigrationExecutionError.unsupportedWalletKind
        }

        if case .trx = feeMethod, prepareResult.hasInsufficientTRX {
            throw WalletMigrationExecutionError.insufficientTronFee
        }

        let sourceAddress: TronSwift.Address
        let destinationAddress: TronSwift.Address
        do {
            sourceAddress = try TronSwift.Address(address: prepareResult.sourceAddress)
            destinationAddress = try TronSwift.Address(address: prepareResult.destinationAddress)
        } catch {
            throw WalletMigrationExecutionError.tronAddressUnavailable
        }

        try await runTronLeg(isDirectBroadcast: !feeMethod.isBattery) {
            let method = TransferMethod(
                to: destinationAddress,
                amount: prepareResult.usdtAmount
            )
            let transaction = try await self.tronUsdtApi.getSendTransaction(
                address: sourceAddress,
                method: method
            )
            let extendedTransaction = try transaction.extendingExpiration(byMilliseconds: 600_000)
            let signature = try await tronSignHandler(extendedTransaction.signingDigest(), sourceWallet)

            var signedTransaction = extendedTransaction
            signedTransaction.signature = signature.hexString()

            try await self.sendSignedTronTransaction(
                signedTransaction: signedTransaction,
                sourceWallet: sourceWallet,
                sourceAddress: sourceAddress,
                feeMethod: feeMethod,
                energy: prepareResult.energy,
                bandwidth: prepareResult.bandwidth
            )
        }
    }

    func executeTronTRXMigration(
        sourceWallet: Wallet,
        prepareResult: WalletMigrationTronPrepareResult,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID,
        allowSkipInsufficient: Bool
    ) async throws(WalletMigrationExecutionError) {
        guard sourceWallet.kind == .regular else {
            throw WalletMigrationExecutionError.unsupportedWalletKind
        }

        if case .trx = feeMethod {
            let reserved = prepareResult.reservedTRX(for: feeMethod)
            if prepareResult.availableTRXSun <= reserved {
                if allowSkipInsufficient {
                    return
                }
                throw WalletMigrationExecutionError.insufficientTronFee
            }
        }

        let sourceAddress: TronSwift.Address
        let destinationAddress: TronSwift.Address
        do {
            sourceAddress = try TronSwift.Address(address: prepareResult.sourceAddress)
            destinationAddress = try TronSwift.Address(address: prepareResult.destinationAddress)
        } catch {
            throw WalletMigrationExecutionError.tronAddressUnavailable
        }

        let preparedAmount = prepareResult.trxTransferAmount(for: feeMethod)
        let initialAmount: BigUInt
        do {
            if preparedAmount > 0 {
                initialAmount = preparedAmount
            } else if let liveAmount = try await resolveLiveTrxSweepAmountSun(
                wallet: sourceWallet,
                from: sourceAddress,
                to: destinationAddress
            ) {
                initialAmount = liveAmount
            } else if allowSkipInsufficient {
                return
            } else {
                throw WalletMigrationExecutionError.insufficientTronFee
            }
        } catch let error as WalletMigrationExecutionError {
            throw error
        } catch {
            if allowSkipInsufficient, WalletMigrationTrxSweep.isInsufficientTrxBalance(error) {
                return
            }
            throw WalletMigrationExecutionError.sendFailed(
                message: WalletMigrationError.sendFailureMessage(from: error)
            )
        }

        do {
            try await broadcastNativeTrxSweep(
                amountSun: initialAmount,
                sourceWallet: sourceWallet,
                sourceAddress: sourceAddress,
                destinationAddress: destinationAddress,
                prepareResult: prepareResult,
                tronSignHandler: tronSignHandler
            )
        } catch is CancellationError {
            throw WalletMigrationExecutionError.sendFailed(message: "Cancelled")
        } catch {
            if WalletMigrationTrxSweep.isInsufficientTrxBalance(error) {
                let retried = try await retryNativeTrxSweepWithLowerAmount(
                    initialAmountSun: initialAmount,
                    sourceWallet: sourceWallet,
                    sourceAddress: sourceAddress,
                    destinationAddress: destinationAddress,
                    prepareResult: prepareResult,
                    tronSignHandler: tronSignHandler
                )
                if retried {
                    return
                }
                if allowSkipInsufficient {
                    return
                }
                throw WalletMigrationExecutionError.insufficientTronFee
            }
            if let error = error as? WalletMigrationExecutionError {
                throw error
            }
            throw WalletMigrationExecutionError.sendFailed(
                message: WalletMigrationError.sendFailureMessage(from: error)
            )
        }
    }

    private func resolveLiveTrxSweepAmountSun(
        wallet: Wallet,
        from: TronSwift.Address,
        to: TronSwift.Address
    ) async throws -> BigUInt? {
        let balanceSun = try await tronUsdtApi.loadTrxBalanceSun(address: from)
        guard balanceSun > 0 else { return nil }

        let estimate = try await tronUsdtApi.estimateNativeTransferFees(
            wallet: wallet,
            from: from,
            to: to,
            amountSun: balanceSun
        )
        let amount = WalletMigrationTrxSweep.transferAmount(
            balanceSun: balanceSun,
            feeSun: estimate.selfPaidTRXSun
        )
        return amount > 0 ? amount : nil
    }

    private func retryNativeTrxSweepWithLowerAmount(
        initialAmountSun: BigUInt,
        sourceWallet: Wallet,
        sourceAddress: TronSwift.Address,
        destinationAddress: TronSwift.Address,
        prepareResult: WalletMigrationTronPrepareResult,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID
    ) async throws(WalletMigrationExecutionError) -> Bool {
        var amountSun = initialAmountSun
        for _ in 0 ..< 4 {
            amountSun = WalletMigrationTrxSweep.reducedAmountSun(amountSun)
            guard amountSun > 0 else { return false }
            do {
                try await broadcastNativeTrxSweep(
                    amountSun: amountSun,
                    sourceWallet: sourceWallet,
                    sourceAddress: sourceAddress,
                    destinationAddress: destinationAddress,
                    prepareResult: prepareResult,
                    tronSignHandler: tronSignHandler
                )
                return true
            } catch is CancellationError {
                throw WalletMigrationExecutionError.sendFailed(message: "Cancelled")
            } catch let error as WalletMigrationExecutionError {
                throw error
            } catch {
                if WalletMigrationTrxSweep.isInsufficientTrxBalance(error) {
                    continue
                }
                return false
            }
        }
        return false
    }

    private func broadcastNativeTrxSweep(
        amountSun: BigUInt,
        sourceWallet: Wallet,
        sourceAddress: TronSwift.Address,
        destinationAddress: TronSwift.Address,
        prepareResult: WalletMigrationTronPrepareResult,
        tronSignHandler: @escaping (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID
    ) async throws {
        // Leftover TRX after a Battery-sponsored USDT leg is always self-paid on-chain, never
        // re-quoted through Battery, so the expiration retry is always safe here.
        do {
            try await TronExpirationRetry.run(isEnabled: true) {
                let transaction = try await self.tronUsdtApi.getNativeTransferTransaction(
                    from: sourceAddress,
                    to: destinationAddress,
                    amountSun: amountSun
                )
                let extendedTransaction = try transaction.extendingExpiration(byMilliseconds: 600_000)
                let signature = try await tronSignHandler(extendedTransaction.signingDigest(), sourceWallet)

                var signedTransaction = extendedTransaction
                signedTransaction.signature = signature.hexString()

                try await self.sendSignedTronTransaction(
                    signedTransaction: signedTransaction,
                    sourceWallet: sourceWallet,
                    sourceAddress: sourceAddress,
                    feeMethod: .trx(amountSun: 0),
                    energy: prepareResult.trxEnergy,
                    bandwidth: prepareResult.trxBandwidth
                )
            }
        } catch is TronTransferSignError {
            throw WalletMigrationExecutionError.signingFailed
        } catch let error as TronApi.Error where error.isInactiveTronAccount {
            throw WalletMigrationExecutionError.inactiveTronAccount
        }
    }

    /// Build, sign and send are one unit: a retry needs a fresh expiration, and a fresh expiration
    /// is a different transaction.
    private func runTronLeg(
        isDirectBroadcast: Bool,
        _ leg: () async throws -> Void
    ) async throws(WalletMigrationExecutionError) {
        do {
            try await TronExpirationRetry.run(isEnabled: isDirectBroadcast, leg)
        } catch {
            throw WalletMigrationTronLegFailure.map(error)
        }
    }

    private func sendSignedTronTransaction(
        signedTransaction: Transaction,
        sourceWallet: Wallet,
        sourceAddress: TronSwift.Address,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod,
        energy: Int,
        bandwidth: Int
    ) async throws {
        if case .battery = feeMethod {
            do {
                try await waitUntilBatteryIdle(wallet: sourceWallet)
            } catch let error as WalletMigrationExecutionError {
                throw error
            } catch {
                throw WalletMigrationExecutionError.sendFailed(
                    message: WalletMigrationError.sendFailureMessage(from: error)
                )
            }
        }

        let feeResolver = TronUSDTFeeOptionsResolver(configuration: configuration)
        let sender = TronUSDTTransactionSender(
            tronUsdtApi: tronUsdtApi,
            feeOptionsResolver: feeResolver
        )
        let resources = TronUSDTTransactionConfirmationState.Resources(
            energy: energy,
            bandwidth: bandwidth
        )

        try await sender.send(
            signedTransaction: signedTransaction,
            selectedExtraType: extraType(for: feeMethod),
            wallet: sourceWallet,
            address: sourceAddress,
            resources: resources,
            instantFeePayment: nil
        )

        // USDT via Battery is accepted before it lands; waiting keeps the TRX sweep from racing
        // ahead and consuming bandwidth the USDT leg still needs on-chain.
        switch try await tronConfirmationWaiter.wait(txId: signedTransaction.txID) {
        case .confirmed:
            return
        case let .failed(result):
            throw WalletMigrationExecutionError.partiallySent(
                message: "Transaction failed: \(result)"
            )
        case .timedOut:
            throw WalletMigrationExecutionError.partiallySent(
                message: "Timeout waiting for TRON transaction"
            )
        }
    }

    private func extraType(
        for feeMethod: WalletMigrationTronPrepareResult.FeeMethod
    ) -> TransactionConfirmationModel.ExtraType {
        switch feeMethod {
        case .battery:
            .battery
        case .trx:
            .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken)
        }
    }
}
