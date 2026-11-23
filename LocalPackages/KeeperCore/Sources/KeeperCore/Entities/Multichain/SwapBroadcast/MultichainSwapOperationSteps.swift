@preconcurrency import ChainKit
import Foundation
import TKLogging

/// What a swap `/v3` prepared asks of chain-kit, the keychain and the chain, apart so a swap can be
/// followed through without a node or a passcode.
protocol MultichainSwapOperationSteps {
    /// What `payload` is signed at: the fee the backend quoted for it, else chain-kit's own price.
    func fee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee

    /// The chain's default fee for `payload`, priced without simulating it.
    func defaultFee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee

    /// Whether `account`'s balance covers `amount` of it sent and `fee` on top.
    func covers(_ amount: BignumBigInteger, and fee: any Fee, from account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> Bool

    /// `asset` as the wallet lists it.
    func details(of asset: any ChainKit.Asset, wallet: Wallet) async -> MultichainAssetDetails

    func unlock(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> MnemonicWallet

    /// Signs each payload at its fee and broadcasts it, in order; the hashes in the same order.
    func send(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet: MnemonicWallet,
        expiresAt: Date,
        fees: [any Fee]
    ) async throws(MultichainSwapExecutionFailure) -> [String]
}

struct ChainKitSwapOperationSteps: MultichainSwapOperationSteps {
    let client: CryptoKitClient
    let unlocker: SwapWalletUnlocker
    let assetDetailsProvider: (String, Wallet) async -> MultichainAssetDetails?

    func fee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee {
        let result: ChainRes<Fee>
        do {
            result = try await mediator(of: account).operation.calculateFee(payload: payload, account: account, priority: .standard)
        } catch {
            throw .emulationFailed(kind: .unknown, reason: "chain kit failed to price payload \(payload.id) due to error: \(error.logDescription)")
        }
        guard let fee = result.getOrNull() else {
            throw .emulationFailed(
                kind: ChainKitErrorKindClassifier.kind(chainError: result.error),
                reason: "chain kit failed to price payload \(payload.id) due to error: \(result.error?.logValue ?? "unknown")"
            )
        }
        return fee
    }

    func defaultFee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee {
        guard let transaction = payload.toTransaction(account: account).getOrNull() else {
            throw .invalidPayload(payloadId: payload.id, reason: "chain kit binds no transaction to the payload")
        }
        do {
            return try await SwapFeeResolver().resolveDefaultFee(mediator: mediator(of: account), transaction: transaction)
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    func covers(_ amount: BignumBigInteger, and fee: any Fee, from account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> Bool {
        let result: NodeRes<GasReserveResult>
        do {
            result = try await client.tx.calculateGasReserve(account: account, energy: account, amount: amount, isMax: false, fee: fee, policy: .drainorerror)
        } catch {
            throw .emulationFailed(kind: .unknown, reason: "chain kit failed to read the balance due to error: \(error.logDescription)")
        }
        guard let reserve = result.getOrNull() else {
            throw .emulationFailed(
                kind: ChainKitErrorKindClassifier.kind(nodeError: result.error),
                reason: "chain kit failed to read the balance due to error: \(result.error?.logValue ?? "unknown")"
            )
        }
        return reserve.error == nil
    }

    func details(of asset: any ChainKit.Asset, wallet: Wallet) async -> MultichainAssetDetails {
        await assetDetailsProvider(asset.id, wallet) ?? MultichainAssetDetails(
            assetId: asset.id,
            name: asset.name,
            symbol: asset.symbol,
            decimals: Int(asset.decimals.value),
            image: ""
        )
    }

    func unlock(
        passcodeProvider: @escaping () async -> String?,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> MnemonicWallet {
        guard case let .hd(wallet) = try await unlocker.unlockSigningWallet(passcodeProvider: passcodeProvider, swapWallet: swapWallet) else {
            throw .internal(reason: "only a wallet's own mnemonic signs a route prepared on /v3")
        }
        return wallet
    }

    func send(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet: MnemonicWallet,
        expiresAt: Date,
        fees: [any Fee]
    ) async throws(MultichainSwapExecutionFailure) -> [String] {
        do {
            // A failed swap is quoted and prepared again, so nothing of it is kept to resume.
            return try await ChainKitOperationSender(client: client).send(
                operation,
                account: account,
                wallet: wallet,
                expiresAt: expiresAt,
                fees: fees,
                persist: { _ in }
            )
        } catch {
            Log.multichainSwap.w("swap operation send failed", error: error, extraInfo: ["operation": operation.id])
            throw Self.failure(error, of: operation)
        }
    }

    static func failure(_ error: any Error, of operation: ChainKit.Operation) -> MultichainSwapExecutionFailure {
        switch error {
        case is CancellationError:
            .canceled
        case ChainKitOperationError.quoteExpired:
            .routeExpired(routeId: operation.id)
        case let ChainKitOperationError.insufficientFunds(payloadId):
            .broadcastFailed(payloadId: payloadId, kind: .insufficientBalance, reason: "the node refused payload \(payloadId) for want of funds")
        case let ChainKitOperationError.nonceUnavailable(reason, kind):
            .nonceFailed(payloadId: operation.payloads.first?.id ?? operation.id, kind: kind, reason: reason)
        case let ChainKitOperationError.signingFailed(payloadId, reason, kind):
            .signingFailed(payloadId: payloadId, kind: kind, reason: reason)
        case let ChainKitOperationError.broadcastFailed(payloadId, _, reason, kind):
            .broadcastFailed(payloadId: payloadId, kind: kind, reason: reason)
        default:
            .internal(reason: error.logDescription)
        }
    }

    private func mediator(of account: ChainKit.Account) -> ChainMediatorWrapper<AnyObject, AnyObject> {
        client.blockchain.getMediator(network: account.chain.network.type)
    }
}
