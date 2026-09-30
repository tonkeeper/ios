@preconcurrency import BigInt
import ChainKit
import CryptoSwift
import Foundation
import TKLogging

struct WalletConnectEVMTransactionSigningUtilities {
    func sign(
        transaction: WalletConnectEVMTransaction,
        send: Bool,
        chain: WalletConnectChain,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard chain.eip155ChainId != nil else {
            throw .invalidTransaction(reason: "chain \(chain.caip2) is not EVM")
        }

        let cryptoWallet = try await context.cryptoWallet()
        let chainKitChain = chain.multichainChain.asChainKitChain
        let accountAddress = try context.accountAddress(chain: chain)

        if let sender = transaction.from, !sender.isEmpty {
            try context.validateSameAddress(expected: accountAddress, actual: sender)
        }

        let account = try chainKitAccount(
            chain: chain,
            addressString: accountAddress,
            cryptoWallet: cryptoWallet
        )
        let feeAsset = chainKitChain.toAsset()
        let wcTransaction = try chainKitTransaction(
            account: account,
            chain: chain,
            payload: transaction,
            feeAsset: feeAsset
        )

        let mediator = context.client.blockchain.getMediator(network: chainKitChain.network.type)
        let fee = try await fee(
            mediator: mediator,
            transaction: wcTransaction,
            payload: transaction,
            chain: chain
        )
        let nonce = try await nonce(
            mediator: mediator,
            account: account,
            payload: transaction
        )
        let signingOutput = try await signAndEncode(
            mediator: mediator,
            transaction: wcTransaction,
            fee: fee,
            nonce: nonce,
            privateKey: cryptoWallet.getPrivateKey(chain: chainKitChain)
        )

        if send {
            do {
                let txHash = try await sendEncoded(
                    mediator: mediator,
                    account: account,
                    signingOutput: signingOutput
                )
                await context.reportPendingTransaction(
                    chain: chain,
                    txHash: txHash,
                    activityType: transaction.pendingActivityType
                )
                return .string(txHash)
            } catch {
                Log.walletConnect.w(
                    "evm transaction send failed",
                    error: error
                )
                throw error
            }
        } else {
            return .string("0x\(signingOutput.asData.hexString())")
        }
    }

    func chainKitAccount(
        chain: WalletConnectChain,
        addressString: String,
        cryptoWallet: CryptoWallet
    ) throws(WalletConnectSigningError) -> ChainKit.Account {
        let chainKitChain = chain.multichainChain.asChainKitChain
        guard let address = Address.Companion.shared.from(value: addressString, chain: chainKitChain, type: .default_) else {
            throw .invalidTransaction(reason: "invalid sender address: \(addressString)")
        }
        return ChainKit.Account(
            address: address,
            asset: chainKitChain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: cryptoWallet.getPublicKey(chain: chainKitChain)
        )
    }

    func chainKitTransaction(
        account: ChainKit.Account,
        chain: WalletConnectChain,
        payload: WalletConnectEVMTransaction,
        feeAsset: AssetCoin
    ) throws(WalletConnectSigningError) -> any ChainKit.Transaction {
        let amount = try bignum(payload.requiredEVMQuantity(.value))
        let data = payload.data.trimmingCharacters(in: .whitespacesAndNewlines)

        if data.isEmpty || data == "0x" {
            guard let to = payload.to,
                  let toAddress = Address.Companion.shared.from(
                      value: to,
                      chain: chain.multichainChain.asChainKitChain,
                      type: .default_
                  )
            else {
                throw .missingRecipient
            }
            return TransactionTransfer(
                account: account,
                amount: amount,
                energy: feeAsset,
                isMax: false,
                to: toAddress,
                memo: nil,
                payload: nil
            )
        } else {
            guard let to = payload.to,
                  let contract = Address.Companion.shared.from(
                      value: to,
                      chain: chain.multichainChain.asChainKitChain,
                      type: .default_
                  )
            else {
                throw .missingRecipient
            }
            return TransactionCall(
                account: account,
                amount: amount,
                energy: feeAsset,
                contract: contract,
                data: data
            )
        }
    }

    func fee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        payload: WalletConnectEVMTransaction,
        chain: WalletConnectChain
    ) async throws(WalletConnectSigningError) -> any Fee {
        if let requestFee = try requestFee(payload: payload, chain: chain) {
            return requestFee
        }

        return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<any Fee, WalletConnectSigningError>, Never>) in
            mediator.fee.calculateFee(transaction: transaction) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToCalculateFee(reason: "chainkit failed to calculate fee: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let value = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToCalculateFee(reason: "chainkit failed to calculate fee: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(value))
            }
        }.get()
    }

    func requestFee(
        payload: WalletConnectEVMTransaction,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) -> (any Fee)? {
        try WalletConnectRequestFeeFactory.requestFee(payload: payload, chain: chain)
    }

    func nonce<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        account: ChainKit.Account,
        payload: WalletConnectEVMTransaction
    ) async throws(WalletConnectSigningError) -> BignumBigInteger {
        if let nonce = try payload.optionalEVMQuantity(.nonce) {
            return bignum(nonce)
        }

        return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<BignumBigInteger, WalletConnectSigningError>, Never>) in
            mediator.account.estimateNonce(account: account) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToEstimateNonce(reason: "chainkit failed to estimate nonce: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let value = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToEstimateNonce(reason: "chainkit failed to estimate nonce: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(value))
            }
        }.get()
    }

    func signAndEncode<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        privateKey: ChainKit.PrivateKey
    ) async throws(WalletConnectSigningError) -> KotlinByteArray {
        let signingOutputs = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<SigSet<KotlinByteArray>, WalletConnectSigningError>, Never>) in
            mediator.sign.transaction.signAndEncode(
                transaction: transaction,
                fee: fee,
                nonce: nonce,
                privateKey: privateKey
            ) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToSign(reason: "chainkit failed to sign transaction: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let value = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToSign(reason: "chainkit failed to sign transaction: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(value))
            }
        }.get()

        guard let output = signingOutputs.outputs.compactMap({ $0 as? KotlinByteArray }).first else {
            throw .failedToSign(reason: "chainkit returned empty signing output")
        }
        return output
    }

    func sendEncoded<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        account: ChainKit.Account,
        signingOutput: KotlinByteArray
    ) async throws(WalletConnectSigningError) -> String {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, WalletConnectSigningError>, Never>) in
            mediator.transaction.sendEncodedTransaction(
                account: account,
                signingOutput: signingOutput
            ) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToSend(reason: "chainkit failed to send transaction: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let txHash = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToSend(reason: "chainkit failed to send transaction: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(txHash as String))
            }
        }.get()
    }

    func bignum(_ value: BigUInt) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.parseString(string: value.description, base: 10)
    }
}
