@preconcurrency import BigInt
import ChainKit
import CryptoSwift
import Foundation
import TKLogging
import typealias WalletCore.EthereumSigningOutput
import WalletCoreSwiftProtobuf

struct WalletConnectEVMTransactionSigningUtilities {
    /// What signs the transaction: the unlocked mnemonic, or a hardware wallet.
    private enum Key {
        case unlocked(MnemonicWallet)
        case device(DeviceTransferSigner)
    }

    struct Call {
        let to: Address
        let value: BignumBigInteger
        let data: String?
    }

    func sign(
        transaction: WalletConnectEVMTransaction,
        send: Bool,
        chain: WalletConnectChain,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard chain.eip155ChainId != nil else {
            throw .invalidTransaction(reason: "chain \(chain.caip2) is not EVM")
        }

        let key: Key
        switch context.signer {
        case .mnemonic:
            key = try await .unlocked(context.cryptoWallet())
        case let .device(device):
            key = .device(device)
        }
        let chainKitChain = chain.multichainChain.asChainKitChain
        let accountAddress = try context.accountAddress(chain: chain)

        if let sender = transaction.from, !sender.isEmpty {
            try context.validateSameAddress(expected: accountAddress, actual: sender, chain: chain)
        }

        let account: ChainKit.Account
        switch key {
        case let .unlocked(cryptoWallet):
            account = try context.chainKitAccount(chain: chain, cryptoWallet: cryptoWallet)
        case .device:
            account = try context.storedChainKitAccount(chain: chain)
        }
        let wcTransaction = try chainKitTransaction(
            account: account,
            chain: chain,
            payload: transaction
        )

        let mediator = context.client.blockchain.getMediator(network: chainKitChain.network.type)
        let fee: any Fee
        if let quotedFee = context.evmFee {
            fee = quotedFee.chainKitFee(chain: chain)
        } else {
            fee = try await calculateFee(mediator: mediator, transaction: wcTransaction)
        }
        let nonce = try await nonce(
            mediator: mediator,
            account: account,
            payload: transaction
        )
        return try await signAndRespond(
            send: send,
            chain: chain,
            activityType: transaction.pendingActivityType,
            context: context,
            sign: { () throws(WalletConnectSigningError) in
                switch key {
                case let .unlocked(cryptoWallet):
                    return try await signAndEncode(
                        mediator: mediator,
                        transaction: wcTransaction,
                        fee: fee,
                        nonce: nonce,
                        privateKey: cryptoWallet.getPrivateKey(chain: chainKitChain)
                    )
                case let .device(device):
                    return try await signOnDevice(
                        mediator: mediator,
                        transaction: wcTransaction,
                        fee: fee,
                        nonce: nonce,
                        chain: chain,
                        device: device
                    )
                }
            },
            broadcast: { output throws(WalletConnectSigningError) in
                try await sendEncoded(mediator: mediator, account: account, signingOutput: output)
            }
        )
    }

    /// An ended request cannot start a broadcast. A broadcast already in flight is still recorded;
    /// only its response to the dApp is discarded then.
    func signAndRespond(
        send: Bool,
        chain: WalletConnectChain,
        activityType: MultichainPendingTransaction.ActivityType,
        context: WalletConnectSigningContext,
        sign: () async throws(WalletConnectSigningError) -> KotlinByteArray,
        broadcast: (KotlinByteArray) async throws(WalletConnectSigningError) -> String
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        try await context.checkRequestIsPending()
        let signingOutput = try await sign()
        try await context.checkRequestIsPending()
        if send {
            let txHash: String
            do {
                txHash = try await broadcast(signingOutput)
            } catch {
                Log.walletConnect.w("evm transaction send failed", error: error)
                throw error
            }
            await context.reportPendingTransaction(chain: chain, txHash: txHash, activityType: activityType)
            try await context.checkRequestIsPending()
            return .string(txHash)
        } else {
            return try .string("0x\(Self.signedTransaction(in: signingOutput).hexString())")
        }
    }

    /// The raw signed transaction a dApp asking for a signature is answered with. Both the wallet's key
    /// and a hardware wallet return a serialized `EthereumSigningOutput`, which only wraps it.
    static func signedTransaction(in signingOutput: KotlinByteArray) throws(WalletConnectSigningError) -> Data {
        let output: EthereumSigningOutput
        do {
            output = try EthereumSigningOutput(serializedBytes: signingOutput.asData)
        } catch {
            throw .failedToSign(reason: "the signer's output is no signed evm transaction: \(error.localizedDescription)")
        }
        guard output.error == .ok, !output.encoded.isEmpty else {
            throw .failedToSign(reason: "the signer returned no signed evm transaction: \(output.errorMessage)")
        }
        return output.encoded
    }

    func quoteFee(
        transaction: WalletConnectEVMTransaction,
        chain: WalletConnectChain,
        wallet: Wallet,
        client: CryptoKitClient
    ) async throws(WalletConnectSigningError) -> WalletConnectEVMFee {
        guard chain.eip155ChainId != nil else {
            throw .invalidTransaction(reason: "chain \(chain.caip2) is not EVM")
        }

        let chainKitChain = chain.multichainChain.asChainKitChain
        guard case let .multichain(state) = wallet.multichain,
              let senderAddress = state.walletAddress(
                  for: chain.multichainChain,
                  preferredType: wallet.preferredMultichainAddressType(for: chain.multichainChain)
              ),
              let address = Address.Companion.shared.from(
                  value: senderAddress.address,
                  chain: chainKitChain,
                  type: senderAddress.type?.chainKitAddressType ?? .default_
              )
        else {
            throw .missingMultichainAddress(chain: chain, walletId: wallet.id)
        }
        let account = ChainKit.Account(
            address: address,
            asset: chainKitChain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: senderAddress.publicKey?.chainKitPubKey
        )

        let fee = try await calculateFee(
            mediator: client.blockchain.getMediator(network: chainKitChain.network.type),
            transaction: chainKitTransaction(account: account, chain: chain, payload: transaction)
        )
        return try WalletConnectEVMFee(fee: fee)
    }

    func chainKitTransaction(
        account: ChainKit.Account,
        chain: WalletConnectChain,
        payload: WalletConnectEVMTransaction
    ) throws(WalletConnectSigningError) -> any ChainKit.Transaction {
        let call = try call(payload, on: chain)
        guard let data = call.data else {
            return TransactionTransfer(
                account: account,
                amount: call.value,
                isMax: false,
                to: call.to,
                memo: nil,
                payload: nil
            )
        }
        return TransactionCall(
            account: account,
            amount: call.value,
            contract: call.to,
            data: data
        )
    }

    /// What a dApp's transaction is signed as: its value to `to`, with its call data trimmed, and
    /// none when that is empty or a bare `0x`.
    func call(
        _ payload: WalletConnectEVMTransaction,
        on chain: WalletConnectChain
    ) throws(WalletConnectSigningError) -> Call {
        let value = try bignum(payload.requiredEVMQuantity(.value))
        let data = payload.data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let to = payload.to,
              let address = Address.Companion.shared.from(
                  value: to,
                  chain: chain.multichainChain.asChainKitChain,
                  type: .default_
              )
        else {
            throw .missingRecipient
        }
        return Call(to: address, value: value, data: data.isEmpty || data == "0x" ? nil : data)
    }

    func calculateFee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction
    ) async throws(WalletConnectSigningError) -> any Fee {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<any Fee, WalletConnectSigningError>, Never>) in
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

    func signOnDevice<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        chain: WalletConnectChain,
        device: DeviceTransferSigner
    ) async throws(WalletConnectSigningError) -> KotlinByteArray {
        do {
            return try await DeviceTransactionSigner.signAndEncode(
                mediator: mediator,
                transaction: transaction,
                fee: fee,
                nonce: nonce,
                chain: chain.multichainChain,
                device: device
            )
        } catch .canceled {
            throw .canceled
        } catch {
            throw .failedToSign(reason: "the device failed to sign the transaction: \(error.logDescription)")
        }
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
