import BigInt
import ChainKit
import Foundation
import OperationReviewModels
import TKLogging

final class ChainKitServiceImplementation: ChainKitService, MultichainRelayedOperationSigner {
    private let supportedChains: [MultichainChain]
    private let mnemonicAccess: MnemonicAccess
    private let client: CryptoKitClient
    private let gate: OperationGate
    private let assetDetailsProvider: (String, Wallet) async -> MultichainAssetDetails?

    init(
        supportedChains: [MultichainChain],
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        gate: OperationGate,
        assetDetailsProvider: @escaping (String, Wallet) async -> MultichainAssetDetails? = { _, _ in nil }
    ) {
        self.supportedChains = supportedChains
        self.mnemonicAccess = mnemonicAccess
        self.client = client
        self.gate = gate
        self.assetDetailsProvider = assetDetailsProvider
    }

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
        commentEncryptionKey: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        let encryptedComment = try Self.encryptedComment(comment, to: commentEncryptionKey, of: asset)
        let (built, feeAsset, networkType, sender) = try transferForEmulationOrSend(
            wallet: wallet,
            recipient: recipient,
            asset: asset,
            amount: amount,
            comment: encryptedComment == nil ? comment : nil,
            isMaxAmount: isMaxAmount,
            accountPublicKey: nil
        )
        var transfer = built
        if let encryptedComment {
            do {
                transfer = try await Self.carrying(transfer, payload: encryptedComment.standIn(account: transfer.account, client: client))
            } catch {
                throw .internal(reason: "chain-kit built no stand-in for the encrypted comment: \(error.logDescription)")
            }
        }
        let mediator = client.blockchain.getMediator(network: networkType)

        let (feeValue, gasReserve) = try await transferPricing(transfer: transfer, feeAsset: feeAsset, mediator: mediator) {
            try await mediator.fee.calculateFee(transaction: transfer)
        }

        let review = await preview(
            Self.adjustedTransfer(transfer, gasReserve: gasReserve),
            from: sender,
            to: recipient,
            intent: .send(amount, of: asset.asset, to: recipient)
        )
        return try await emulation(fee: feeValue, feeAsset: feeAsset, gasReserve: gasReserve, isMaxAmount: isMaxAmount, review: review, wallet: wallet)
    }

    func emulateOperationTransfer(
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        let encryptedComment = try Self.encryptedComment(comment, to: commentEncryptionKey, of: asset)
        let (transfer, feeAsset, networkType, sender) = try transferForEmulationOrSend(
            wallet: wallet,
            recipient: recipient,
            asset: asset,
            amount: amount,
            comment: encryptedComment == nil ? comment : nil,
            isMaxAmount: isMaxAmount,
            accountPublicKey: nil
        )
        let mediator = client.blockchain.getMediator(network: networkType)
        return try await operationEmulation(
            of: transfer,
            feeAsset: feeAsset,
            from: sender,
            to: recipient,
            intent: .send(amount, of: asset.asset, to: recipient),
            wallet: wallet,
            encryptedComment: encryptedComment
        ) { payload, account async throws(MultichainTransactionEmulationFailure) in
            try await self.transferPricing(transfer: transfer, feeAsset: feeAsset, mediator: mediator) {
                try await mediator.operation.calculateFee(payload: payload, account: account, priority: .standard)
            }
        }
    }

    func sendMultichainTransfer(
        signer: MultichainTransferSigner,
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount: Bool,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String] {
        guard let chain = asset.asset.chain else {
            throw .internal(
                reason: "failed to determine chain for asset id \(asset.asset.assetId)"
            )
        }
        let encryptedComment: MultichainEncryptedComment?
        do {
            encryptedComment = try Self.encryptedComment(comment, to: commentEncryptionKey, of: asset)
        } catch {
            throw .emulationFailure(error)
        }
        let key: TransferKey
        switch signer {
        case let .mnemonic(passcodeProvider):
            key = try await .unlocked(unlockCryptoWallet(passcodeProvider: passcodeProvider, wallet: wallet))
        case let .device(device):
            guard DeviceTransactionSigner.canSign(chain) else {
                throw .internal(reason: "a hardware wallet cannot sign a \(chain.rawValue) transfer")
            }
            key = .device(device)
        }

        var transfer: TransactionTransfer
        let feeAsset: AssetCoin
        let networkType: ChainKit.Network.Type_
        let sender: MultichainWalletAddress
        do {
            (transfer, feeAsset, networkType, sender) = try transferForEmulationOrSend(
                wallet: wallet,
                recipient: recipient,
                asset: asset,
                amount: amount,
                comment: encryptedComment == nil ? comment : nil,
                isMaxAmount: isMaxAmount,
                accountPublicKey: key.unlocked?.getPublicKey(
                    chain: chain.asChainKitChain
                )
            )
        } catch {
            throw .emulationFailure(error)
        }
        if let encryptedComment {
            // The keys encrypt it: a device that signs alone never hands them over.
            guard case let .unlocked(unlocked) = key else {
                throw .internal(reason: "a hardware wallet cannot encrypt a comment")
            }
            do {
                transfer = try await Self.carrying(transfer, payload: encryptedComment.encrypted(account: transfer.account, wallet: unlocked, client: client))
            } catch {
                throw .failedToSign(kind: .unknown, reason: "the comment could not be encrypted: \(error.logDescription)")
            }
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
        return try await signAndSend(
            transfer,
            from: sender,
            to: recipient,
            intent: .send(amount, of: asset.asset, to: recipient),
            consent: consent,
            steps: TransferSteps(
                nonce: { transfer async throws(MultichainTransactionFailure) in
                    try await Self.nonce(of: transfer, mediator: mediator)
                },
                sign: { transfer, nonce async throws(MultichainTransactionFailure) in
                    try await Self.signingOutputs(of: transfer, fee: fee, nonce: nonce, key: key, chain: chain, mediator: mediator)
                },
                broadcast: { transfer, signingOutput async throws(MultichainTransactionFailure) in
                    try await Self.broadcast(signingOutput, of: transfer, mediator: mediator)
                }
            )
        )
    }

    func sendOperationTransfer(
        _ emulation: MultichainTransactionEmulationResult,
        wallet: Wallet,
        passcodeProvider: @escaping () async -> String?,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String] {
        guard let priced = emulation.operation else {
            throw .internal(reason: "the transfer was priced as no operation to sign")
        }
        guard !emulation.isInsufficientBalance else {
            throw .emulationFailure(
                .chainError(
                    kind: .insufficientBalance,
                    reason: "gas reserve reported insufficient balance"
                )
            )
        }
        return try await send(
            priced,
            consent: consent,
            steps: OperationSteps(
                unlock: { () async throws(MultichainTransactionFailure) -> MnemonicWallet in
                    try await self.unlockCryptoWallet(passcodeProvider: passcodeProvider, wallet: wallet)
                },
                send: { [client] operation, account, unlocked, fee async throws(MultichainTransactionFailure) -> [String] in
                    do {
                        // A send has no quote to expire, and nothing of it is kept to resume.
                        return try await ChainKitOperationSender(client: client).send(
                            operation,
                            account: account,
                            wallet: unlocked,
                            expiresAt: .distantFuture,
                            fees: [fee],
                            persist: { _ in }
                        )
                    } catch {
                        Log.chainKit.w("Payment of an own send failed", error: error)
                        throw Self.sendFailure(error)
                    }
                }
            )
        )
    }

    func signRelayedOperation(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        chain: MultichainChain,
        operation: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        let chainKitWallet = try await unlockCryptoWallet(passcodeProvider: passcodeProvider, wallet: wallet)
        let account: ChainKit.Account
        do {
            account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
            try ChainKitOperationSender.verifyKeys(of: account, unlocked: chainKitWallet)
        } catch {
            throw .internal(reason: "relayed operation is not the wallet's to sign: \(error.logDescription)")
        }
        return try await Self.signRelayedOperation(
            operation,
            account: account,
            wallet: chainKitWallet,
            client: client
        )
    }

    /// Signs every payload of `operation` with the unlocked `wallet` for `account` and returns the
    /// envelope the relayer takes, `{"operation": {"id": …, "payloads": [ … ]}}`, as ChainKit
    /// writes it.
    static func signRelayedOperation(
        _ operation: MultichainRelayedOperation,
        account: ChainKit.Account,
        wallet chainKitWallet: MnemonicWallet,
        client: CryptoKitClient
    ) async throws(MultichainTransactionFailure) -> Data {
        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        // Relayer documents carry their own nonce and cost the sender no gas: neither argument is read.
        let zero = BignumBigInteger.Companion.shared.parseString(string: "0", base: 10)
        let noFee = FeeValue(asset: account.chain.toAsset(), amount: zero)

        var signedPayloads = [SignedPayload]()
        for payload in operation.operation.payloads {
            let result: SignRes<SignedPayload>
            do {
                result = try await mediator.operation.sign(
                    payload: payload,
                    account: account,
                    fee: noFee,
                    nonce: zero,
                    wallet: chainKitWallet
                )
            } catch {
                throw .failedToSign(
                    kind: .unknown,
                    reason: "chain kit failed to sign relayed payload \(payload.id) due to error: \(error.logDescription)"
                )
            }
            guard let signed = result.getOrNull() else {
                let error = result.error?.logValue ?? "unknown"
                throw .failedToSign(
                    kind: ChainKitErrorKindClassifier.kind(signError: result.error),
                    reason: "chain kit failed to sign relayed payload \(payload.id) due to error: \(error)"
                )
            }
            signedPayloads.append(signed)
        }

        // Read as text: the ObjC export hands the JSON object itself over as a dictionary.
        return Data(SignedOperation(id: operation.id, payloads: signedPayloads).toJsonString().utf8)
    }

    func signBatteryPurchase(
        wallet: Wallet,
        request: BatteryPurchaseRequest,
        shown: BatteryPurchaseReview,
        passcodeProvider: @escaping () async -> String?,
        refresh: () async throws -> BatteryPurchaseReview
    ) async throws -> (Data, BatteryPurchaseReview) {
        try Task.checkCancellation()
        let unlocked = try await unlockCryptoWallet(passcodeProvider: passcodeProvider, wallet: wallet)
        try Task.checkCancellation()
        // Solana's blockhash can expire before the quote's stated deadline: rebuild after the PIN.
        let fresh = try await refresh()
        try BatteryPurchaser.checkFresh(fresh, against: shown)
        guard !fresh.isExpired(at: Date()), let chain = request.method.chain,
              let address = wallet.multichainWalletState?.walletAddress(for: chain, preferredType: wallet.preferredMultichainAddressType(for: chain)),
              BatteryAssetRechargeMethod.sameAddress(address.address, request.sender),
              let asset = AssetCompanion.shared.fromString(assetId: request.method.assetId, name: request.method.symbol, symbol: request.method.symbol, decimals: Int32(request.method.decimals))
        else { throw BatteryPurchaseError.invalidQuote }
        let account = try ChainKitOperationSender.account(of: address, asset: asset)
        try ChainKitOperationSender.verifyKeys(of: account, unlocked: unlocked)
        try BatteryPurchaseOperationGuard.check(fresh.response.operation, request: request)
        let json = try JSONEncoder().encode(fresh.response.operation)
        let allowed = chain.isEVM ? MultichainRelayedOperation.relayedTypes : [ChainKit.Payload.Type_.prebuild]
        let operation = try MultichainRelayedOperation(id: fresh.response.operation.id, json: String(decoding: json, as: UTF8.self), allowedTypes: allowed)
        guard !operation.operation.payloads.isEmpty else { throw BatteryPurchaseError.invalidQuote }
        let signable = SignableOperation(
            operation: operation.operation,
            account: account,
            intent: .wallet(spending: [.init(assetId: request.method.assetId, symbol: request.method.symbol, decimals: request.method.decimals, amount: request.amount)], to: fresh.quote.fundsReceiver),
            fidelity: .exact
        )
        let configured = gate.checks()
        let checks = configured.contains(where: { $0 is ChainKitValidationCheck }) ? configured : [ChainKitValidationCheck(client: client)] + configured
        let purchaseGate = OperationGate(checks: { checks })
        try await purchaseGate.clear(.ask, consent: OperationConsent { review in
            !review.findings.contains { $0.severity == .danger || $0.failure != nil }
        }) { [signable] }
        try Task.checkCancellation()
        let signed = try await Self.signRelayedOperation(operation, account: account, wallet: unlocked, client: client)
        guard !fresh.isExpired(at: Date()) else { throw BatteryPurchaseError.expired }
        return (signed, fresh)
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
            walletId: wallet.walletIdV2(),
            addresses: addresses
        )
    }

    func makeWalletRegisterItem(
        appPrivateKey: Data,
        deviceId: String,
        challenge: String,
        state: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem {
        let accounts = state.addresses.filter { supportedChains.contains($0.chain) }
        let proofAccounts: [ChainKit.Account] = try accounts.map { try makeProofAccount(address: $0) }
        guard !proofAccounts.isEmpty else {
            throw ChainKitWalletSyncRequestError.emptyAccounts
        }
        let keyPair = try Self.walletKeyPair(appPrivateKey: appPrivateKey, walletId: state.walletId)
        defer { keyPair.privateKey.fillZeros() }
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
        let keyPair = wallet.walletKeyPair()
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
        let keyPair = wallet.walletKeyPair()
        defer { keyPair.privateKey.fillZeros() }
        return keyPair.privateKey.asData
    }

    func walletAuthToken(appPrivateKey: Data, walletId: String, accessToken: String) -> String? {
        let keyPair: WalletKeyPair
        do {
            keyPair = try Self.walletKeyPair(appPrivateKey: appPrivateKey, walletId: walletId)
        } catch {
            Log.w("🪵 WalletAuth: no token, the kept key is not the app key of wallet \(walletId)", error: error)
            return nil
        }
        defer { keyPair.privateKey.fillZeros() }
        return client.auth.walletAuthToken(keyPair: keyPair, accessToken: accessToken)
    }

    /// The auth key pair of the wallet `walletId` names. The id carries the wallet's kind, and so its signing scheme,
    /// and a key that is not that wallet's is refused here rather than signed with.
    static func walletKeyPair(appPrivateKey: Data, walletId: String) throws -> WalletKeyPair {
        let privateKey = appPrivateKey.asKotlinByteArray
        guard let keyPair = WalletKeyPair.companion.fromPrivateKey(privateKey: privateKey, walletId: walletId).getOrNull() else {
            privateKey.fillZeros()
            throw ChainKitWalletSyncRequestError.appKeyMismatch
        }
        return keyPair
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
    /// What signs a built transfer: the unlocked mnemonic, or a hardware wallet.
    enum TransferKey {
        case unlocked(MnemonicWallet)
        case device(DeviceTransferSigner)

        var unlocked: MnemonicWallet? {
            guard case let .unlocked(wallet) = self else {
                return nil
            }
            return wallet
        }
    }

    enum ChainKitWalletSyncRequestError: LoggableError {
        case emptyAccounts
        case invalidAccount(address: String)
        case appKeyMismatch

        var logDescription: String {
            switch self {
            case .emptyAccounts:
                return "type=ChainKitWalletSyncRequestError, case=emptyAccounts"
            case .invalidAccount:
                return "type=ChainKitWalletSyncRequestError, case=invalidAccount"
            case .appKeyMismatch:
                return "type=ChainKitWalletSyncRequestError, case=appKeyMismatch"
            }
        }
    }

    func makeCryptoWallet(mnemonic: String) throws -> MnemonicWallet {
        try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: normalize(mnemonic: mnemonic)
        )
    }

    /// Asks for the passcode and derives the keys that sign for the wallet on every chain.
    func unlockCryptoWallet(
        passcodeProvider: () async -> String?,
        wallet: Wallet
    ) async throws(MultichainTransactionFailure) -> MnemonicWallet {
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
        do {
            return try makeCryptoWallet(mnemonic: phrase)
        } catch {
            throw .internal(reason: "failed to derive multichain wallet: \(error.logDescription)")
        }
    }

    static func nonce<I, O>(
        of transfer: TransactionTransfer,
        mediator: ChainMediatorWrapper<I, O>
    ) async throws(MultichainTransactionFailure) -> BignumBigInteger {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<BignumBigInteger, MultichainTransactionFailure>, Never>) in
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
    }

    static func signingOutputs<I, O>(
        of transfer: TransactionTransfer,
        fee: any Fee,
        nonce: BignumBigInteger,
        key: TransferKey,
        chain: MultichainChain,
        mediator: ChainMediatorWrapper<I, O>
    ) async throws(MultichainTransactionFailure) -> [KotlinByteArray] {
        switch key {
        case let .unlocked(chainKitWallet):
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
                case .ton, .eth, .base, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
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
            return signingOutputs.outputs.compactMap { $0 as? KotlinByteArray }
        case let .device(device):
            return try await[DeviceTransactionSigner.signAndEncode(
                mediator: mediator,
                transaction: transfer,
                fee: fee,
                nonce: nonce,
                chain: chain,
                device: device
            )]
        }
    }

    static func broadcast<I, O>(
        _ signingOutput: KotlinByteArray,
        of transfer: TransactionTransfer,
        mediator: ChainMediatorWrapper<I, O>
    ) async throws(MultichainTransactionFailure) -> String {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, MultichainTransactionFailure>, Never>) in
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
        case .eth, .base, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
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

    /// `transfer` at the fee `price` gives, of the transfer itself or of chain-kit's operation for it.
    /// A chain that prices a transfer by emulating it cannot price one the wallet has no coin to
    /// send: the node rejects the message before execution, and the failure arrives untyped. The
    /// gas reserve answers the same question from the balance, so put the chain's default fee to it
    /// before reporting the pricing failure — a transfer the wallet cannot pay for belongs on the
    /// confirmation screen as a shortage, the same as one that priced successfully.
    func transferPricing<I, O>(
        transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        mediator: ChainMediatorWrapper<I, O>,
        price: () async throws -> ChainRes<Fee>
    ) async throws(MultichainTransactionEmulationFailure) -> (fee: Fee, reserve: GasReserveResult) {
        let feeResult: ChainRes<Fee>
        do {
            feeResult = try await price()
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

    func emulation(
        fee: Fee,
        feeAsset: AssetCoin,
        gasReserve: GasReserveResult,
        isMaxAmount: Bool,
        review: OperationReview?,
        operation: PricedOperation? = nil,
        wallet: Wallet
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        guard let amount = BigUInt(fee.amount.description) else {
            throw .internal(
                reason: "fee amount value is not a number: \(fee.amount.description)"
            )
        }
        let feeAssetDetails = await assetDetailsProvider(feeAsset.id, wallet)
        return MultichainTransactionEmulationResult(
            fee: amount,
            asset: feeAssetDetails ?? MultichainAssetDetails(
                assetId: feeAsset.id,
                name: feeAsset.name,
                symbol: feeAsset.symbol,
                decimals: Int(feeAsset.decimals.value),
                image: ""
            ),
            adjustedAmount: gasReserve.isAmountAdjusted ? BigUInt(gasReserve.amount.description) : nil,
            isMaxAmount: isMaxAmount || gasReserve.isAmountAdjusted,
            isInsufficientBalance: gasReserve.error != nil,
            review: review,
            operation: operation
        )
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
        networkType: ChainKit.Network.Type_,
        sender: MultichainWalletAddress
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
            isMax: isMaxAmount,
            to: recipientAddress,
            memo: comment,
            payload: nil
        )
        return (transfer, feeAsset, chain.asChainKitChain.network.type, senderWalletAddress)
    }
}

extension ChainKitServiceImplementation {
    /// The node and the signer a reviewed transfer is handed to, passed in so the order they are
    /// reached in can be pinned without a node.
    struct TransferSteps {
        let nonce: (TransactionTransfer) async throws(MultichainTransactionFailure) -> BignumBigInteger
        let sign: (TransactionTransfer, BignumBigInteger) async throws(MultichainTransactionFailure) -> [KotlinByteArray]
        let broadcast: (TransactionTransfer, KotlinByteArray) async throws(MultichainTransactionFailure) -> String
    }

    /// What a reviewed operation is unlocked for and sent through, passed in so the order they are
    /// reached in can be pinned without a passcode or a node.
    struct OperationSteps {
        let unlock: () async throws(MultichainTransactionFailure) -> MnemonicWallet
        /// Signs the operation from the account with the unlocked keys at the fee, sends it and
        /// returns its hashes.
        let send: (ChainKit.Operation, ChainKit.Account, MnemonicWallet, any Fee) async throws(MultichainTransactionFailure) -> [String]
    }

    /// A copy of what the SDK signs is built from the inputs its intent is, so it has next to nothing
    /// to be held to: what the checks find in it is only logged. An operation chain-kit signs as it
    /// stands is asked about instead.
    private static let presentation = OperationPresentation.logOnly

    /// The review of `transfer` as the emulation prices it, read the way the gate before its signature
    /// reads it.
    func preview(
        _ transfer: TransactionTransfer,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent
    ) async -> OperationReview? {
        await gate.preview(Self.presentation) {
            try await transferSignables(transfer, from: sender, to: recipient, intent: intent)
        }
    }

    /// Clears `transfer` as it is about to be signed, then reads its nonce, signs and broadcasts it:
    /// a transfer the gate refuses has nothing read for it, signed or sent.
    func signAndSend(
        _ transfer: TransactionTransfer,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent,
        consent: OperationConsent,
        steps: TransferSteps
    ) async throws(MultichainTransactionFailure) -> [String] {
        // Before the nonce is read, so however long the review takes cannot leave it stale.
        try await clear(Self.presentation, consent: consent) {
            try await transferSignables(transfer, from: sender, to: recipient, intent: intent)
        }
        let nonce = try await steps.nonce(transfer)
        let outputs = try await steps.sign(transfer, nonce)
        guard !outputs.isEmpty else {
            throw .internal(reason: "empty or nil signing outputs")
        }
        var txHashes = [String]()
        for signingOutput in outputs {
            try await txHashes.append(steps.broadcast(transfer, signingOutput))
        }
        return txHashes
    }

    /// `transfer` as chain-kit's own operation for it, priced and reviewed as that operation, which is
    /// then signed at that fee: `price` gives the fee of its payload and the gas reserve at that fee.
    /// What the reserve leaves of a max send costs the chain what the whole amount does, so the
    /// operation is built again for it and not priced again.
    /// An `encryptedComment` is priced and reviewed as chain-kit's stand-in of its size, the body the
    /// operation carries until the send encrypts the comment into its place.
    func operationEmulation(
        of transfer: TransactionTransfer,
        feeAsset: AssetCoin,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent,
        wallet: Wallet,
        encryptedComment: MultichainEncryptedComment? = nil,
        price: (Payload, ChainKit.Account) async throws(MultichainTransactionEmulationFailure) -> (fee: Fee, reserve: GasReserveResult)
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        let requested = try await operation(of: transfer, from: sender, to: recipient, intent: intent, encryptedComment: encryptedComment)
        guard let payload = requested.operation.payloads.first else {
            throw .internal(reason: "chain-kit's operation for the transfer has no payload")
        }
        let (fee, gasReserve) = try await price(payload, requested.account)
        let signable = if gasReserve.isAmountAdjusted {
            try await operation(
                of: Self.adjustedTransfer(transfer, gasReserve: gasReserve),
                from: sender,
                to: recipient,
                intent: intent,
                encryptedComment: encryptedComment
            )
        } else {
            requested
        }
        let review = await gate.preview(.ask) { [signable] }
        return try await emulation(
            fee: fee,
            feeAsset: feeAsset,
            gasReserve: gasReserve,
            isMaxAmount: transfer.isMax,
            review: review,
            operation: PricedOperation(
                signable: signable,
                fee: gasReserve.isAmountAdjusted ? Self.draining(fee) : fee,
                encryptedComment: encryptedComment
            ),
            wallet: wallet
        )
    }

    /// `fee` with the tip the SDK signs a whole balance at, the whole EIP-1559 max fee: the gas the
    /// reserve kept back is then spent, and the address is left empty rather than with dust.
    private static func draining(_ fee: Fee) -> Fee {
        guard let fee = fee as? FeeEip1559 else {
            return fee
        }
        return fee.doCopy(
            asset: fee.asset,
            limit: fee.limit,
            networkPrice: fee.networkPrice,
            maxPrice: fee.maxPrice,
            minerPrice: fee.maxPrice,
            amount: fee.amount
        )
    }

    /// Clears the operation the transfer was priced as before the passcode is asked for, then has it
    /// signed at that fee and sent: an operation the gate refuses is never unlocked for.
    func send(
        _ priced: PricedOperation,
        consent: OperationConsent,
        steps: OperationSteps
    ) async throws(MultichainTransactionFailure) -> [String] {
        let consented = ConsentedFindings()
        try await clear(.ask, consent: consented.recording(consent)) { [priced.signable] }
        let unlocked = try await steps.unlock()
        let account: ChainKit.Account
        do {
            account = try ChainKitOperationSender.account(priced.signable.account, signedBy: unlocked)
        } catch {
            throw .internal(reason: "the reviewed operation is not the unlocked wallet's to sign: \(error.logDescription)")
        }
        // The passcode released the payment: closing the screen no longer stops it, as it does not stop
        // the SDK's send, so it goes out in a task the screen's cancellation does not reach.
        let sending = Task { [gate, client] () async -> Result<[String], MultichainTransactionFailure> in
            do throws(MultichainTransactionFailure) {
                let operation = try await Self.authorized(
                    priced,
                    consented: consented.all,
                    account: account,
                    unlocked: unlocked,
                    gate: gate,
                    client: client
                )
                return try await .success(steps.send(operation, account, unlocked, priced.fee))
            } catch {
                return .failure(error)
            }
        }
        return try await sending.value.get()
    }

    /// The operation `priced` stands for, as the unlocked keys make it. An encrypted comment takes the
    /// place of the stand-in it was priced and reviewed as, and is held to what the user consented to on
    /// the swipe: a danger that is none of the `consented` findings stops the send.
    static func authorized(
        _ priced: PricedOperation,
        consented: Set<ConsentedFinding>,
        account: ChainKit.Account,
        unlocked: MnemonicWallet,
        gate: OperationGate,
        client: CryptoKitClient
    ) async throws(MultichainTransactionFailure) -> ChainKit.Operation {
        guard let comment = priced.encryptedComment else {
            return priced.signable.operation
        }
        let signable: SignableOperation
        do {
            signable = try await priced.signable.carrying(body: comment.encrypted(account: account, wallet: unlocked, client: client))
        } catch {
            throw .failedToSign(kind: .unknown, reason: "the comment could not be encrypted: \(error.logDescription)")
        }
        let unread = OperationConsent { review in
            !review.findings.contains { $0.severity == .danger && !consented.contains(ConsentedFinding($0)) }
        }
        do throws(OperationRefusal) {
            try await gate.clear(.ask, consent: unread) { [signable] }
        } catch .declined {
            throw .internal(reason: "the encrypted comment's operation shows a danger the user did not read")
        } catch {
            throw .internal(reason: "the encrypted comment's operation could not be reviewed: \(error)")
        }
        return signable.operation
    }

    /// A finding as the user consented to it: what was found and about what, on whichever operation.
    struct ConsentedFinding: Hashable, Sendable {
        let kind: String
        let subject: String?
        let details: String?

        init(_ finding: OperationFinding) {
            kind = finding.kind
            subject = finding.subject
            details = finding.details
        }
    }

    /// The findings of the reviews a consent let through.
    actor ConsentedFindings {
        private(set) var all = Set<ConsentedFinding>()

        /// `consent`, keeping the findings of every review it lets through.
        nonisolated func recording(_ consent: OperationConsent) -> OperationConsent {
            OperationConsent { review in
                guard await consent(review) else {
                    return false
                }
                await self.insert(review.findings)
                return true
            }
        }

        private func insert(_ findings: [OperationFinding]) {
            all.formUnion(findings.map(ConsentedFinding.init))
        }
    }

    /// The comment of `asset`'s send encrypted to `key`, or none to encrypt.
    static func encryptedComment(
        _ comment: String?,
        to key: String?,
        of asset: MultichainAsset
    ) throws(MultichainTransactionEmulationFailure) -> MultichainEncryptedComment? {
        guard let encrypted = MultichainEncryptedComment(text: comment, key: key) else {
            return nil
        }
        guard MultichainEncryptedComment.isCarried(by: asset) else {
            throw .unsupportedAsset(id: asset.asset.assetId)
        }
        return encrypted
    }

    /// `transfer` with `payload` as the body of its message in place of its comment: chain-kit holds the
    /// two apart.
    static func carrying(_ transfer: TransactionTransfer, payload: String) -> TransactionTransfer {
        TransactionTransfer(
            account: transfer.account,
            amount: transfer.amount,
            isMax: transfer.isMax,
            to: transfer.to,
            memo: nil,
            payload: payload
        )
    }

    static func sendFailure(_ error: any Error) -> MultichainTransactionFailure {
        switch error {
        case is CancellationError:
            .canceled
        case let ChainKitOperationError.insufficientFunds(payloadId):
            .failedToSendSigned(kind: .insufficientBalance, reason: "the node refused payload \(payloadId) for want of funds")
        case let ChainKitOperationError.nonceUnavailable(reason, kind):
            .failedToEstimateNonce(kind: kind, reason: reason)
        case let ChainKitOperationError.signingFailed(_, reason, kind):
            .failedToSign(kind: kind, reason: reason)
        case let ChainKitOperationError.broadcastFailed(_, _, reason, kind):
            .failedToSendSigned(kind: kind, reason: reason)
        default:
            .internal(reason: error.logDescription)
        }
    }

    /// The gate on what is about to be signed. A refusal fails the send: a decline as the user's
    /// cancellation, anything else as no cancellation.
    private func clear(
        _ presentation: OperationPresentation,
        consent: OperationConsent,
        _ build: () async throws -> [SignableOperation]
    ) async throws(MultichainTransactionFailure) {
        do throws(OperationRefusal) {
            try await gate.clear(presentation, consent: consent, build)
        } catch .declined {
            throw .canceled
        } catch {
            throw .internal(reason: "the transfer could not be reviewed: \(error)")
        }
    }

    private func transferSignables(
        _ transfer: TransactionTransfer,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent
    ) async throws -> [SignableOperation] {
        try await[signable(of: transfer, from: sender, to: recipient, intent: intent, fidelity: .converted)]
    }

    private func operation(
        of transfer: TransactionTransfer,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent,
        encryptedComment: MultichainEncryptedComment?
    ) async throws(MultichainTransactionEmulationFailure) -> SignableOperation {
        do {
            let signable = try await signable(of: transfer, from: sender, to: recipient, intent: intent, fidelity: .exact)
            guard let encryptedComment else {
                return signable
            }
            return try await signable.carrying(body: encryptedComment.standIn(account: signable.account, client: client))
        } catch {
            throw .internal(reason: "chain-kit built no operation for the transfer: \(error.logDescription)")
        }
    }

    /// chain-kit's own payload for `transfer`, held by the account of the address it is sent from with
    /// the key that address stored, not the unlocked one: the preview and the gate then read the same
    /// transfer as the same review.
    private func signable(
        of transfer: TransactionTransfer,
        from sender: MultichainWalletAddress,
        to recipient: String,
        intent: OperationIntent,
        fidelity: SignableOperation.Fidelity
    ) async throws -> SignableOperation {
        try await .transfer(
            from: ChainKitOperationSender.account(of: sender, asset: transfer.account.asset),
            to: recipient,
            amount: transfer.amount,
            memo: transfer.memo,
            isMax: transfer.isMax,
            intent: intent,
            fidelity: fidelity,
            client: client
        )
    }

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

extension MultichainWalletAddressType {
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
