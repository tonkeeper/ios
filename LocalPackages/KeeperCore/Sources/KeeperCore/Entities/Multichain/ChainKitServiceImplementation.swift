import BigInt
import ChainKit
import Foundation
import TKLogging

final class ChainKitServiceImplementation: ChainKitService {
    private let supportedChains: [MultichainChain]
    private let mnemonicAccess: MnemonicAccess
    private let client: CryptoKitClient
    private let assetDetailsProvider: (String, Wallet) async -> MultichainAssetDetails?

    init(
        supportedChains: [MultichainChain],
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        assetDetailsProvider: @escaping (String, Wallet) async -> MultichainAssetDetails? = { _, _ in nil }
    ) {
        self.supportedChains = supportedChains
        self.mnemonicAccess = mnemonicAccess
        self.client = client
        self.assetDetailsProvider = assetDetailsProvider
    }

    static let walletKind: ChainKit.WalletKind = .multichain
    func isTransferSupported(asset: MultichainAsset) -> Bool {
        guard asset.asset.chain != nil else {
            return false
        }
        return chainKitAsset(asset: asset) != nil
    }

    func emulateTransaction(
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        let (transfer, feeAsset, networkType) = try transferForEmulationOrSend(
            wallet: wallet,
            recipient: recipient,
            asset: asset,
            amount: amount,
            comment: comment,
            isMaxAmount: isMaxAmount,
            accountPublicKey: nil
        )
        let mediator = client.blockchain.getMediator(network: networkType)

        let (feeValue, gasReserve) = try await transferPricing(
            transfer: transfer,
            feeAsset: feeAsset,
            mediator: mediator
        )

        guard let fee = BigUInt(feeValue.amount.description) else {
            throw .internal(
                reason: "fee amount value is not a number: \(feeValue.amount.description)"
            )
        }

        let adjustedAmount = gasReserve.isAmountAdjusted ? BigUInt(gasReserve.amount.description) : nil

        let feeAssetDetails = await assetDetailsProvider(feeAsset.id, wallet)

        return MultichainTransactionEmulationResult(
            fee: fee,
            asset: feeAssetDetails ?? MultichainAssetDetails(
                assetId: feeAsset.id,
                name: feeAsset.name,
                symbol: feeAsset.symbol,
                decimals: Int(feeAsset.decimals.value),
                image: ""
            ),
            adjustedAmount: adjustedAmount,
            isMaxAmount: isMaxAmount || gasReserve.isAmountAdjusted,
            isInsufficientBalance: gasReserve.error != nil
        )
    }

    func sendMultichainTransfer(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionFailure) -> [String] {
        guard let chain = asset.asset.chain else {
            throw .internal(
                reason: "failed to determine chain for asset id \(asset.asset.assetId)"
            )
        }
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }
        let phrase: String
        do {
            let coreMnemonic = try await mnemonicAccess.getMnemonic(
                wallet: wallet,
                passcode: passcode
            )
            phrase = coreMnemonic.mnemonicWords.joined(separator: " ")
        } catch {
            let message = "failed to read mnemonic during multichain transfer"
            Log.e(message, error: error)
            throw .internal(reason: "\(message): \(error.logDescription)")
        }
        let chainKitWallet: CryptoWallet
        do {
            chainKitWallet = try CryptoWallet.Companion.shared.fromMnemonic(
                mnemonic_: normalize(mnemonic: phrase)
            )
        } catch {
            throw .internal(reason: "failed to derive multichain wallet: \(error.logDescription)")
        }

        var transfer: TransactionTransfer
        let feeAsset: AssetCoin
        let networkType: ChainKit.Network.Type_
        do {
            (transfer, feeAsset, networkType) = try transferForEmulationOrSend(
                wallet: wallet,
                recipient: recipient,
                asset: asset,
                amount: amount,
                comment: comment,
                isMaxAmount: isMaxAmount,
                accountPublicKey: chainKitWallet.getPublicKey(
                    chain: chain.asChainKitChain
                )
            )
        } catch {
            throw .emulationFailure(error)
        }
        let mediator = client.blockchain.getMediator(network: networkType)

        let feeResult: ChainRes<Fee>
        do {
            feeResult = try await mediator.fee.calculateFee(transaction: transfer)
        } catch {
            throw .emulationFailure(
                .internal(
                    reason: "chain kit failed to calculate fee due to unknown error: \(error.logDescription)"
                )
            )
        }
        guard let fee = feeResult.getOrNull() else {
            let error = feeResult.error?.logValue ?? "unknown"
            throw .emulationFailure(
                .chainError(
                    kind: ChainKitErrorKindClassifier.kind(chainError: feeResult.error),
                    reason: "chain kit failed to calculate fee due to error: \(error)"
                )
            )
        }

        let gasReserve: GasReserveResult
        do {
            gasReserve = try await transferGasReserve(transfer: transfer, feeAsset: feeAsset, fee: fee)
        } catch {
            throw .emulationFailure(error)
        }
        guard gasReserve.error == nil else {
            throw .emulationFailure(
                .chainError(
                    kind: .insufficientBalance,
                    reason: "gas reserve reported insufficient balance"
                )
            )
        }
        transfer = Self.adjustedTransfer(transfer, gasReserve: gasReserve)

        let nonce = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<BignumBigInteger, MultichainTransactionFailure>, Never>) in
            mediator.account.estimateNonce(account: transfer.account) { result, error in
                if let error {
                    return continuation.resume(
                        returning: .failure(
                            .failedToEstimateNonce(
                                kind: .unknown,
                                reason: "chain kit failed to estimate nonce due to error: \(error.logDescription)"
                            )
                        )
                    )
                }
                guard let value = result?.getOrNull() else {
                    let chainKitError = result.flatMap(\.error)
                    let error = chainKitError.map(\.logValue) ?? "unknown"
                    return continuation.resume(
                        returning: .failure(
                            .failedToEstimateNonce(
                                kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                                reason: "chain kit failed to estimate nonce due to error: \(error)"
                            )
                        )
                    )
                }
                continuation.resume(returning: .success(value))
            }
        }.get()

        let signingOutputs = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<SigSet<KotlinByteArray>, MultichainTransactionFailure>, Never>) in
            let handler: @Sendable (SignRes<SigSet<KotlinByteArray>>?, Error?) -> Void = { result, error in
                if let error {
                    return continuation.resume(
                        returning: .failure(
                            .failedToSign(
                                kind: .unknown,
                                reason: "chain kit failed to sign transaction due to error: \(error.logDescription)"
                            )
                        )
                    )
                }
                guard let value = result?.getOrNull() else {
                    let chainKitError = result.flatMap(\.error)
                    let error = chainKitError.map(\.logValue) ?? "unknown"
                    return continuation.resume(
                        returning: .failure(
                            .failedToSign(
                                kind: ChainKitErrorKindClassifier.kind(signError: chainKitError),
                                reason: "chain kit failed to sign transaction due to error: \(error)"
                            )
                        )
                    )
                }
                continuation.resume(returning: .success(value))
            }
            switch chain {
            case .btc:
                mediator.sign.transaction.signAndEncode(
                    transaction: transfer,
                    fee: fee,
                    nonce: nonce,
                    wallet: chainKitWallet,
                    completionHandler: handler
                )
            case .ton, .eth, .base, .tron, .arb, .bsc:
                mediator.sign.transaction.signAndEncode(
                    transaction: transfer,
                    fee: fee,
                    nonce: nonce,
                    privateKey: chainKitWallet.getPrivateKey(
                        chain: chain.asChainKitChain
                    ),
                    completionHandler: handler
                )
            }
        }.get()

        let outputs: [KotlinByteArray] = signingOutputs.outputs.compactMap { $0 as? KotlinByteArray }
        guard !outputs.isEmpty else {
            throw .internal(
                reason: "empty or nil signing outputs"
            )
        }

        var txHashes = [String]()
        for signingOutput in outputs {
            let txHash = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, MultichainTransactionFailure>, Never>) in
                mediator.transaction.sendEncodedTransaction(
                    account: transfer.account,
                    signingOutput: signingOutput
                ) { result, error in
                    if let error {
                        return continuation.resume(
                            returning: .failure(
                                .failedToSendSigned(
                                    kind: .unknown,
                                    reason: "chain kit failed to send encoded transaction due to error: \(error.logDescription)"
                                )
                            )
                        )
                    }
                    guard let value = result?.getOrNull() else {
                        let chainKitError = result.flatMap(\.error)
                        let error = chainKitError.map(\.logValue) ?? "unknown"
                        return continuation.resume(
                            returning: .failure(
                                .failedToSendSigned(
                                    kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                                    reason: "chain kit failed to send encoded transaction due to error: \(error)"
                                )
                            )
                        )
                    }
                    continuation.resume(returning: .success(value as String))
                }
            }.get()
            txHashes.append(txHash)
        }
        return txHashes
    }

    func makeWalletState(mnemonic: String) throws -> MultichainWalletState {
        let wallet = try makeCryptoWallet(mnemonic: mnemonic)
        let addresses = supportedChains.flatMap { chain in
            let publicKey = wallet.getPublicKey(chain: chain.asChainKitChain).multichainPublicKey
            return addressTypes(for: chain).map { addressType, walletAddressType in
                MultichainWalletAddress(
                    chain: chain,
                    address: wallet.getAddress(
                        chain: chain.asChainKitChain,
                        type: addressType
                    ).display,
                    type: walletAddressType,
                    publicKey: publicKey
                )
            }
        }
        return MultichainWalletState(
            walletId: wallet.walletIdV2(kind: Self.walletKind),
            addresses: addresses
        )
    }

    func makeWalletRegisterItem(
        mnemonic: String,
        deviceId: String,
        challenge: String,
        state: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem {
        let wallet = try makeCryptoWallet(mnemonic: mnemonic)
        let accounts = state.addresses.filter { supportedChains.contains($0.chain) }
        let proofAccounts: [ChainKit.Account] = try accounts.map { try makeProofAccount(address: $0) }
        guard !proofAccounts.isEmpty else {
            throw ChainKitWalletSyncRequestError.emptyAccounts
        }
        let keyPair = wallet.walletKeyPair(kind: Self.walletKind)
        let proof = client.auth.signWalletRegisterProofV2(
            keyPair: keyPair,
            deviceId: deviceId,
            challenge: challenge,
            accounts: proofAccounts
        )
        return MultichainWalletRegisterItem(
            walletId: proof.walletId,
            walletProof: proof.signature,
            accounts: accounts
        )
    }

    func addresses(mnemonic: String) -> [MultichainWalletAddress] {
        do {
            return try makeWalletState(mnemonic: mnemonic).addresses
        } catch {
            Log.w("🪵 Multichain: address derivation failed", error: error)
            return []
        }
    }

    func tronPrivateKey(mnemonic: String) throws -> Data {
        let wallet = try makeCryptoWallet(mnemonic: mnemonic)
        return wallet
            .getPrivateKey(chain: MultichainChain.tron.asChainKitChain)
            .data()
            .asData
    }

    func makeBatterySendProof(
        mnemonic: String,
        walletId: String,
        boc: String
    ) throws -> String {
        let wallet = try makeCryptoWallet(mnemonic: mnemonic)
        let keyPair = wallet.walletKeyPair(kind: Self.walletKind)
        defer { keyPair.privateKey.fillZeros() }
        return client.auth.signBatterySendProof(
            keyPair: keyPair,
            walletId: walletId,
            chain: "ton",
            boc: boc
        ).signature
    }

    func walletAppPrivateKey(mnemonic: String) throws -> Data {
        let wallet = try makeCryptoWallet(mnemonic: mnemonic)
        let keyPair = wallet.walletKeyPair(kind: Self.walletKind)
        defer { keyPair.privateKey.fillZeros() }
        return keyPair.privateKey.asData
    }

    func walletAuthToken(appPrivateKey: Data, accessToken: String) -> String {
        let privateKey = appPrivateKey.asKotlinByteArray
        defer { privateKey.fillZeros() }
        let keyPair = WalletKeyPair.companion.fromPrivateKey(
            privateKey: privateKey,
            kind: Self.walletKind
        )
        defer { keyPair.privateKey.fillZeros() }
        return client.auth.walletAuthToken(keyPair: keyPair, accessToken: accessToken)
    }

    func makeMnemonic() throws(MultichainMakeMnemonicFailure) -> [String] {
        var mnemonicWords: [String]?
        Mnemonic(
            value: MnemonicGenerator.shared.generateFrom(size: .b128)
        ).toWords().useAndClear { words in
            for index in 0 ..< words.size {
                guard let word = words.get(index: index) as? String else {
                    mnemonicWords = nil
                    return
                }
                if mnemonicWords == nil {
                    mnemonicWords = []
                }
                mnemonicWords?.append(word)
            }
        }
        guard let mnemonicWords else {
            throw .unknown(message: "makeMnemonic: unexpected nil from chainkit")
        }
        return mnemonicWords
    }

    private func normalize(mnemonic: String) -> String {
        mnemonic
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension ChainKitServiceImplementation {
    enum ChainKitWalletSyncRequestError: LoggableError {
        case emptyAccounts
        case invalidAccount(address: String)

        var logDescription: String {
            switch self {
            case .emptyAccounts:
                return "type=ChainKitWalletSyncRequestError, case=emptyAccounts"
            case .invalidAccount:
                return "type=ChainKitWalletSyncRequestError, case=invalidAccount"
            }
        }
    }

    func makeCryptoWallet(mnemonic: String) throws -> CryptoWallet {
        try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: normalize(mnemonic: mnemonic)
        )
    }

    func addressTypes(for chain: MultichainChain) -> [(Address.Type_, MultichainWalletAddressType?)] {
        switch chain {
        case .ton:
            return [
                (.tonv4r2, .tonV4R2),
                (.tonv5r1, .tonV5R1),
            ]
        case .btc:
            return [(.btcsegwit, .btcP2WPKH)]
        case .eth, .base, .tron, .arb, .bsc:
            return [(.default_, nil)]
        }
    }

    func makeProofAccount(address: MultichainWalletAddress) throws -> ChainKit.Account {
        let chain = address.chain.asChainKitChain
        guard let chainKitAddress = Address.Companion.shared.from(
            value: address.address,
            chain: chain,
            type: address.type?.chainKitAddressType ?? .default_
        ) else {
            throw ChainKitWalletSyncRequestError.invalidAccount(address: address.address)
        }
        return ChainKit.Account.Companion.shared.watch(
            address: chainKitAddress,
            asset: chain.toAsset(),
            derivation: DerivationDefaultPath.shared
        )
    }

    /// A chain that prices a transfer by emulating it cannot price one the wallet has no coin to
    /// send: the node rejects the message before execution, and the failure arrives untyped. The
    /// gas reserve answers the same question from the balance, so put the chain's default fee to it
    /// before reporting the pricing failure — a transfer the wallet cannot pay for belongs on the
    /// confirmation screen as a shortage, the same as one that priced successfully.
    func transferPricing<I, O>(
        transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        mediator: ChainMediatorWrapper<I, O>
    ) async throws(MultichainTransactionEmulationFailure) -> (fee: Fee, reserve: GasReserveResult) {
        let feeResult: ChainRes<Fee>
        do {
            feeResult = try await mediator.fee.calculateFee(transaction: transfer)
        } catch {
            throw .internal(
                reason: "chain kit failed to calculate fee due to thrown error: \(error.logDescription)"
            )
        }
        guard let feeValue = feeResult.getOrNull() else {
            let error = feeResult.error?.logValue ?? "unknown"
            let failure = MultichainTransactionEmulationFailure.chainError(
                kind: ChainKitErrorKindClassifier.kind(chainError: feeResult.error),
                reason: "chain kit failed to calculate fee due to error: \(error)"
            )
            return try await unpayableTransferPricing(
                transfer: transfer,
                feeAsset: feeAsset,
                mediator: mediator,
                failure: failure
            )
        }
        let reserve = try await transferGasReserve(transfer: transfer, feeAsset: feeAsset, fee: feeValue)
        return (feeValue, reserve)
    }

    func unpayableTransferPricing<I, O>(
        transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        mediator: ChainMediatorWrapper<I, O>,
        failure: MultichainTransactionEmulationFailure
    ) async throws(MultichainTransactionEmulationFailure) -> (fee: Fee, reserve: GasReserveResult) {
        let defaultResult: ChainRes<Fee>
        do {
            defaultResult = try await mediator.fee.getDefaultFee(transaction: transfer)
        } catch {
            throw failure
        }
        guard let defaultFee = defaultResult.getOrNull() else {
            throw failure
        }
        let reserve: GasReserveResult
        do {
            reserve = try await transferGasReserve(transfer: transfer, feeAsset: feeAsset, fee: defaultFee)
        } catch {
            throw failure
        }
        guard reserve.error != nil else {
            throw failure
        }
        Log.multichain.w(
            "transfer pricing failed on a wallet short of the chain coin",
            error: failure,
            extraInfo: ["feeAsset": feeAsset.id]
        )
        return (defaultFee, reserve)
    }

    func transferGasReserve(
        transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        fee: Fee
    ) async throws(MultichainTransactionEmulationFailure) -> GasReserveResult {
        let energy = ChainKit.Account(
            address: transfer.account.address,
            asset: feeAsset,
            derivation: DerivationDefaultPath.shared,
            publicKey: transfer.account.publicKey
        )
        let reserveResult: NodeRes<GasReserveResult>
        do {
            reserveResult = try await client.tx.calculateGasReserve(
                account: transfer.account,
                energy: energy,
                amount: transfer.amount,
                isMax: transfer.isMax,
                fee: fee,
                policy: .drainorerror
            )
        } catch {
            throw .internal(
                reason: "chain kit failed to calculate gas reserve due to error: \(error.logDescription)"
            )
        }
        guard let reserve = reserveResult.getOrNull() else {
            let chainKitError = reserveResult.error
            let errorText = chainKitError.map(\.logValue) ?? "unknown"
            throw .chainError(
                kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                reason: "chain kit failed to calculate gas reserve due to error: \(errorText)"
            )
        }
        return reserve
    }

    func transferForEmulationOrSend(
        wallet: Wallet,
        recipient recipientAddressString: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool,
        accountPublicKey: PubKey?
    ) throws(MultichainTransactionEmulationFailure) -> (
        transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        networkType: ChainKit.Network.Type_
    ) {
        guard let chain = asset.asset.chain else {
            throw .unsupportedAsset(id: asset.asset.assetId)
        }
        let chainAsset = chainKitAsset(asset: asset)

        guard let chainAsset else {
            throw .unsupportedAsset(id: asset.asset.assetId)
        }

        guard case let .multichain(state) = wallet.multichain,
              !state.addresses.isEmpty
        else {
            throw .unsupportedChain(chain)
        }

        let preferredType = wallet.preferredMultichainAddressType(for: chain)

        guard let senderWalletAddress = state.walletAddress(for: chain, preferredType: preferredType) else {
            throw .unsupportedChain(chain)
        }

        let senderAddressString = senderWalletAddress.address

        guard let senderAddress = Address.Companion.shared.from(
            value: senderAddressString,
            chain: chain.asChainKitChain,
            type: senderWalletAddress.type?.chainKitAddressType ?? .default_
        ) else {
            throw .invalidSenderAddress(senderAddressString)
        }

        guard let recipientAddress = Address.Companion.shared.from(
            value: recipientAddressString,
            chain: chain.asChainKitChain,
            type: .default_
        ) else {
            throw .invalidRecipientAddress(recipientAddressString)
        }

        let resolvedPublicKey = accountPublicKey ?? senderWalletAddress.publicKey?.chainKitPubKey

        let account = ChainKit.Account(
            address: senderAddress,
            asset: chainAsset,
            derivation: DerivationDefaultPath.shared,
            publicKey: resolvedPublicKey
        )

        let feeAsset = chainAsset.chain.toAsset()

        let transfer = TransactionTransfer(
            account: account,
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            energy: feeAsset,
            isMax: isMaxAmount,
            to: recipientAddress,
            memo: comment,
            payload: nil
        )
        return (transfer, feeAsset, chain.asChainKitChain.network.type)
    }
}

extension ChainKitServiceImplementation {
    static func adjustedTransfer(
        _ transfer: TransactionTransfer,
        gasReserve: GasReserveResult
    ) -> TransactionTransfer {
        guard gasReserve.isAmountAdjusted else {
            return transfer
        }
        return TransactionTransfer(
            account: transfer.account,
            amount: gasReserve.amount,
            energy: transfer.energy,
            isMax: true,
            to: transfer.to,
            memo: transfer.memo,
            payload: transfer.payload
        )
    }
}

private func chainKitAsset(asset: MultichainAsset) -> Asset? {
    AssetCompanion.shared.fromString(
        assetId: asset.asset.assetId,
        name: asset.asset.name,
        symbol: asset.asset.symbol,
        decimals: Int32(asset.asset.decimals)
    )
}

private extension PubKey {
    var multichainPublicKey: MultichainPublicKey {
        MultichainPublicKey(defaultHex: defaultHex, segWit: segWit)
    }
}

extension MultichainPublicKey {
    var chainKitPubKey: PubKey {
        PubKey(defaultHex: defaultHex, segWit: segWit)
    }
}

private extension MultichainWalletAddressType {
    var chainKitAddressType: Address.Type_ {
        switch self {
        case .tonV3R1, .tonV3R2, .tonV4R1:
            return .default_
        case .tonV4R2:
            return .tonv4r2
        case .tonV5R1:
            return .tonv5r1
        case .btcP2PKH, .btcP2SHP2WPKH:
            return .default_
        case .btcP2WPKH:
            return .btcsegwit
        case .btcP2TR:
            return .btcstaproot
        }
    }
}
