import ChainKit
import Foundation
import TKLogging

enum ChainKitOperationError: Error, Equatable {
    case quoteExpired
    case malformed(String)
    case unsupportedAccount(String)
    /// The unlocked keys are not the ones the account was quoted for.
    case keyMismatch(expected: String, unlocked: String)
    case feeUnavailable(payloadId: String, reason: String)
    /// The node refused the payload for want of funds, so it never went out.
    case insufficientFunds(payloadId: String)
    case nonceUnavailable(String, kind: MultichainSwapExecutionErrorKind = .unknown)
    case staleAuthorization(payloadId: String)
    case signingFailed(payloadId: String, reason: String, kind: MultichainSwapExecutionErrorKind = .unknown)
    /// The RPC outcome is ambiguous; signed bytes must be retained for an idempotent retry.
    case broadcastFailed(payloadId: String, sent: [String], reason: String, kind: MultichainSwapExecutionErrorKind = .unknown)
}

extension ChainKitOperationError: LoggableError {
    var logDescription: String {
        String(describing: self)
    }
}

struct ChainKitSignedTransaction: Sendable, Equatable, Codable {
    let payloadId: String
    let nonce: String
    let data: String
    var hash: String?
    var acknowledged: Bool
    var broadcastAttempted = false
}

/// Prices, signs and broadcasts a Generic Payload API operation through ChainKit's per-chain
/// operation delegates, one payload at a time and in the operation's order.
struct ChainKitOperationSender {
    private typealias Mediator = ChainMediatorWrapper<AnyObject, AnyObject>

    /// How long a payload the chain cannot price before the previous one lands waits for it.
    static let confirmationTimeout: TimeInterval = 120
    private static let confirmationPollNanoseconds: UInt64 = 3_000_000_000
    private static let noBlock = BignumBigInteger.Companion.shared.parseString(string: "0", base: 10)

    let client: CryptoKitClient
    private let readNonce: ((ChainKit.Account) async throws -> BignumBigInteger)?

    /// `readNonce` answers for the node in a test; without it the account's chain is asked.
    init(client: CryptoKitClient, readNonce: ((ChainKit.Account) async throws -> BignumBigInteger)? = nil) {
        self.client = client
        self.readNonce = readNonce
    }

    static func parse(id: String, payloads: String) throws -> ChainKit.Operation {
        let result = ChainKit.Operation.Companion.shared.parse(id: id, meta: payloads)
        guard let operation = result.getOrNull() else {
            throw ChainKitOperationError.malformed(result.error?.message ?? "unknown")
        }
        return operation
    }

    /// The sender as the wallet's multichain state names it, the address the backend quotes
    /// for, holding `asset`: the coin its fees are paid in when `nil`.
    static func account(wallet: Wallet, chain: MultichainChain, holding asset: MultichainAssetDetails? = nil) throws -> ChainKit.Account {
        guard let sender = wallet.multichainWalletState?.walletAddress(
            for: chain,
            preferredType: wallet.preferredMultichainAddressType(for: chain)
        ) else {
            throw ChainKitOperationError.unsupportedAccount(chain.rawValue)
        }
        return try asset.map { try account(of: sender, holding: $0) } ?? account(of: sender, asset: nil)
    }

    /// The account of the wallet's own TON address holding its coin: the one a multichain wallet
    /// names, or a legacy wallet's, which no backend knows.
    static func tonAccount(of wallet: Wallet) throws -> ChainKit.Account {
        if wallet.isMultichain {
            return try account(wallet: wallet, chain: .ton)
        }
        guard let address = wallet.legacySwapWallet?.walletAddress(for: .ton) else {
            throw ChainKitOperationError.unsupportedAccount(MultichainChain.ton.rawValue)
        }
        return try account(of: address, asset: nil)
    }

    /// The account of `address` holding `asset`, its chain's coin when `nil`. Built from the
    /// address that signs and its stored key alone, so a wallet without a multichain state — a
    /// legacy swap or TRON wallet — has one too.
    static func account(of address: MultichainWalletAddress, asset: Asset?) throws -> ChainKit.Account {
        let chain = address.chain.asChainKitChain
        // The account's chain is its asset's: an asset of another chain would put the address there.
        guard asset.map({ $0.chain.id == chain.id }) ?? true,
              let signer = Address.Companion.shared.from(
                  value: address.address,
                  chain: chain,
                  type: address.type?.chainKitAddressType ?? .default_
              )
        else {
            throw ChainKitOperationError.unsupportedAccount(address.chain.rawValue)
        }
        return ChainKit.Account(
            address: signer,
            asset: asset ?? chain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: address.publicKey?.chainKitPubKey
        )
    }

    /// The account of `address` holding `asset`, a token or its chain's coin, as the wallet lists it.
    static func account(of address: MultichainWalletAddress, holding asset: MultichainAssetDetails) throws -> ChainKit.Account {
        guard let decimals = Int32(exactly: asset.decimals),
              let held = AssetCompanion.shared.fromString(
                  assetId: asset.assetId,
                  name: asset.name,
                  symbol: asset.symbol,
                  decimals: decimals
              )
        else {
            throw ChainKitOperationError.unsupportedAccount(asset.assetId)
        }
        return try account(of: address, asset: held)
    }

    /// One fee per payload; `nil` for a payload the chain cannot price yet — typically a
    /// payment behind an approval that is not on chain, when the backend quoted no gas for it.
    func fees(of operation: ChainKit.Operation, account: ChainKit.Account) async -> [Fee?] {
        let mediator = mediator(of: account)
        var fees = [Fee?]()
        for payload in operation.payloads {
            fees.append(try? await fee(of: payload, account: account, mediator: mediator))
        }
        return fees
    }

    /// Returns the hashes in the operation's order. The nonce is read once and handed out one
    /// per payload, so no payload waits for the one before it to be mined — unless the chain
    /// cannot price it until then. A payload is signed at the fee `fees` holds at its index, the
    /// one the user confirmed, and priced as it is signed only without one. Given a
    /// `startingNonce`, the one a dApp asked for, the first payload is signed at it and the chain
    /// is not asked; a send resumed from `saved` keeps the nonces it signed at.
    func send(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet: MnemonicWallet,
        expiresAt: Date,
        fees: [(any Fee)?],
        startingNonce: BignumBigInteger? = nil,
        saved: [ChainKitSignedTransaction] = [],
        persist: (ChainKitSignedTransaction) async throws -> Void
    ) async throws -> [String] {
        try Self.verifyKeys(of: account, unlocked: wallet)
        let mediator = mediator(of: account)
        var nonce: BignumBigInteger
        if let first = saved.first {
            nonce = BignumBigInteger.Companion.shared.parseString(string: first.nonce, base: 10)
        } else if let startingNonce {
            nonce = startingNonce
        } else {
            nonce = try await self.nonce(of: account, mediator: mediator)
        }
        var hashes = [String]()
        for (index, payload) in operation.payloads.enumerated() {
            var transaction: ChainKitSignedTransaction
            if let stored = saved.first(where: { $0.payloadId == payload.id }) {
                transaction = stored
                nonce = BignumBigInteger.Companion.shared.parseString(string: stored.nonce, base: 10)
            } else {
                try Self.checkDeadline(expiresAt)
                if !saved.isEmpty {
                    let current = try await self.nonce(of: account, mediator: mediator)
                    if current.compareTo(other: nonce) > 0 { nonce = current }
                }
                transaction = try await signed(
                    payload,
                    of: operation,
                    account: account,
                    wallet: wallet,
                    nonce: nonce,
                    confirmed: fees.indices.contains(index) ? fees[index] : nil,
                    after: hashes.last,
                    expiresAt: expiresAt
                )
                try Self.checkDeadline(expiresAt)
                try await persist(transaction)
                try Self.checkDeadline(expiresAt)
            }
            if !transaction.acknowledged {
                try await Self.prepareBroadcast(&transaction, expiresAt: expiresAt, persist: persist)
                do {
                    transaction.hash = try await broadcast(transaction, payload: payload, account: account)
                } catch let ChainKitOperationError.insufficientFunds(payloadId) {
                    // Refused outright, it is no payment that may have been sent; the same bytes go out on a retry.
                    transaction.broadcastAttempted = false
                    try await persist(transaction)
                    throw ChainKitOperationError.insufficientFunds(payloadId: payloadId)
                }
                transaction.acknowledged = true
                try await persist(transaction)
            }
            guard let hash = transaction.hash else { throw ChainKitOperationError.malformed(payload.id) }
            hashes.append(hash)
            nonce = nonce.inc()
        }
        return hashes
    }

    /// Signs every payload in the operation's order and sends none: each at the fee `fees` holds at its
    /// index, or at chain-kit's price without one; the first at `startingNonce`, the one a dApp asked
    /// for, or else at the account's next, and each next one a nonce later. Nothing is kept, broadcast
    /// or recorded.
    func sign(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet: MnemonicWallet,
        fees: [(any Fee)?],
        startingNonce: BignumBigInteger? = nil
    ) async throws -> [ChainKitSignedTransaction] {
        try Self.verifyKeys(of: account, unlocked: wallet)
        let mediator = mediator(of: account)
        var nonce: BignumBigInteger
        if let startingNonce {
            nonce = startingNonce
        } else {
            nonce = try await self.nonce(of: account, mediator: mediator)
        }
        var transactions = [ChainKitSignedTransaction]()
        for (index, payload) in operation.payloads.enumerated() {
            try await transactions.append(signed(
                payload,
                of: operation,
                account: account,
                wallet: wallet,
                nonce: nonce,
                confirmed: fees.indices.contains(index) ? fees[index] : nil,
                after: nil,
                expiresAt: .distantFuture
            ))
            nonce = nonce.inc()
        }
        return transactions
    }

    /// `payload` signed at `nonce` with the `confirmed` fee, or else at the price chain-kit gives it
    /// now — after `previous` lands when the chain cannot price it before.
    private func signed(
        _ payload: Payload,
        of operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet: MnemonicWallet,
        nonce: BignumBigInteger,
        confirmed: (any Fee)?,
        after previous: String?,
        expiresAt: Date
    ) async throws -> ChainKitSignedTransaction {
        let mediator = mediator(of: account)
        let fee: Fee
        if let confirmed {
            fee = confirmed
        } else {
            do {
                fee = try await self.fee(of: payload, account: account, mediator: mediator)
            } catch {
                guard let previous else { throw error }
                try await waitForConfirmation(of: previous, account: account, mediator: mediator, expiresAt: expiresAt)
                fee = try await self.fee(of: payload, account: account, mediator: mediator)
            }
        }
        try Self.checkDeadline(expiresAt)
        try Self.checkAuthorization(of: payload, nonce: nonce)
        let signed = try await sign(payload, account: account, fee: fee, nonce: nonce, wallet: wallet, mediator: mediator)
        let raw = try JSONDecoder().decode(String.self, from: Data(signed.data.description.utf8))
        let hash = try Self.transactionHash(of: signed, payloadId: payload.id, mediator: mediator)
        Log.chainKit.i("Payment signed operation=\(operation.id) payload=\(payload.id) chain=\(account.chain.name) hash=\(hash ?? "unknown")", extraInfo: ["nonce": nonce.description, "fee": fee.amount.description, "fee_asset": fee.asset.id])
        return ChainKitSignedTransaction(payloadId: payload.id, nonce: nonce.description, data: raw, hash: hash, acknowledged: false)
    }

    /// Signs every payload as a document a relayer submits — an EIP-7702 authorization, an
    /// EIP-712 `Execute` — so nothing is broadcast and no nonce of the sender's is spent. Each
    /// signed payload is the JSON ChainKit writes for it, by payload id.
    func signDocuments(_ operation: ChainKit.Operation, account: ChainKit.Account, wallet: MnemonicWallet) async throws -> [String: String] {
        let mediator = mediator(of: account)
        // A document is never broadcast: nothing to price, so no round trip to the node.
        let fee = FeeNone(asset: account.asset)
        var signed = [String: String]()
        for payload in operation.payloads {
            signed[payload.id] = try await sign(payload, account: account, fee: fee, nonce: Self.noBlock, wallet: wallet, mediator: mediator).toJsonString()
        }
        return signed
    }

    /// A message payload, a dApp's text that never goes on chain, signed with the unlocked keys: nothing
    /// to price and no nonce to spend. Returns the signature as chain-kit writes it.
    func signMessage(_ payload: Payload, account: ChainKit.Account, wallet: MnemonicWallet) async throws -> String {
        try Self.verifyKeys(of: account, unlocked: wallet)
        let signed = try await sign(payload, account: account, fee: FeeNone(asset: account.asset), nonce: Self.noBlock, wallet: wallet, mediator: mediator(of: account))
        return try JSONDecoder().decode(String.self, from: Data(signed.data.description.utf8))
    }

    /// TON and Bitcoin derive the sender from the key, so the key is what has to match.
    static func verifyKeys(of account: ChainKit.Account, unlocked wallet: MnemonicWallet) throws {
        if let expected = account.publicKey?.defaultHex {
            let unlocked = wallet.getPublicKey(chain: account.chain).defaultHex
            guard unlocked.lowercased() == expected.lowercased() else {
                throw ChainKitOperationError.keyMismatch(expected: expected, unlocked: unlocked)
            }
        } else {
            let unlocked = wallet.getAddress(chain: account.chain, type: account.address.type).display
            guard unlocked.lowercased() == account.addressDisplay.lowercased() else {
                throw ChainKitOperationError.keyMismatch(expected: account.addressDisplay, unlocked: unlocked)
            }
        }
    }

    /// `reviewed` as the unlocked keys sign from it. Its review was read with the key its address
    /// stored, which the review id carries; where that key is another or missing, the account takes
    /// the unlocked key once the address is that key's own.
    static func account(_ reviewed: ChainKit.Account, signedBy wallet: MnemonicWallet) throws -> ChainKit.Account {
        let key = wallet.getPublicKey(chain: reviewed.chain)
        if reviewed.publicKey?.defaultHex.lowercased() == key.defaultHex.lowercased() {
            return reviewed
        }
        try verifyKeys(
            of: ChainKit.Account(address: reviewed.address, asset: reviewed.asset, derivation: reviewed.derivation, publicKey: nil),
            unlocked: wallet
        )
        return ChainKit.Account(address: reviewed.address, asset: reviewed.asset, derivation: reviewed.derivation, publicKey: key)
    }

    static func checkAuthorization(of payload: Payload, nonce: BignumBigInteger) throws {
        guard let authorization = (payload.meta as? PayloadMetaEvmMain)?.authorization,
              authorization.nonce != nonce.inc()
        else { return }
        throw ChainKitOperationError.staleAuthorization(payloadId: payload.id)
    }

    static func prepareBroadcast(_ transaction: inout ChainKitSignedTransaction, expiresAt: Date, now: () -> Date = { Date() }, persist: (ChainKitSignedTransaction) async throws -> Void) async throws {
        try checkDeadline(expiresAt, now: now())
        if !transaction.broadcastAttempted {
            transaction.broadcastAttempted = true
            try await persist(transaction)
            do {
                try checkDeadline(expiresAt, now: now())
            } catch {
                transaction.broadcastAttempted = false
                try await persist(transaction)
                throw error
            }
        }
    }

    static func checkDeadline(_ expiresAt: Date, now: Date = Date()) throws {
        try Task.checkCancellation()
        guard expiresAt > now else { throw ChainKitOperationError.quoteExpired }
    }

    /// The node's id for the signed bytes, known before they go out; `nil` on a chain ChainKit cannot derive it for.
    private static func transactionHash(of signed: SignedPayload, payloadId: String, mediator: Mediator) throws -> String? {
        let result = mediator.operation.transactionHash(payload: signed)
        if let hash = result.getOrNull() { return hash as String }
        if result.error is OpError.UnsupportedChain { return nil }
        Log.chainKit.w("Payment hash unavailable payload=\(payloadId) reason=\(result.error?.message ?? "unknown")")
        throw ChainKitOperationError.malformed(payloadId)
    }

    func broadcast(_ transaction: ChainKitSignedTransaction, payload: Payload, account: ChainKit.Account) async throws -> String {
        let mediator = mediator(of: account)
        let signed = SignedPayload.Companion.shared.signed(payload: payload, data: transaction.data)
        let context = "payload=\(payload.id) chain=\(account.chain.name) hash=\(transaction.hash ?? "unknown")"
        let started = Date()
        let safeDiagnostics = mediator.debug.broadcastDiagnostics(payload: signed)
        var diagnostics = safeDiagnostics.getOrNull() as? [String: String] ?? [:]
        if account.chain is ChainTronMainnet {
            if let error = safeDiagnostics.error {
                diagnostics["diagnostics_error"] = error.message ?? String(describing: error)
            }
            diagnostics["sender"] = account.addressDisplay
            if let meta = payload.meta as? PayloadMetaTronMain {
                diagnostics["quoted_to"] = meta.to.display
                diagnostics["quoted_value"] = meta.value.description
                diagnostics["quoted_data"] = meta.data ?? "none"
            }
            diagnostics["broadcast_at_ms"] = String(Int64(started.timeIntervalSince1970 * 1000))
            diagnostics["broadcast_attempted"] = String(transaction.broadcastAttempted)
        }
        Log.chainKit.i("Payment broadcast started \(context)", extraInfo: diagnostics)
        do {
            let result = try await mediator.broadcastAndReconcile(payload: signed, account: account)
            if let hash = result.getOrNull() {
                Log.chainKit.i("Payment broadcast accepted \(context) received=\(hash) elapsed_ms=\(started.pretty.msSinceNow)")
                return hash as String
            }
            if Self.isInsufficientFunds(result.error) { throw ChainKitOperationError.insufficientFunds(payloadId: payload.id) }
            throw ChainKitOperationError.broadcastFailed(
                payloadId: payload.id,
                sent: [],
                reason: result.error?.logValue ?? "unknown",
                kind: ChainKitErrorKindClassifier.kind(nodeError: result.error)
            )
        } catch {
            Log.chainKit.w("Payment broadcast failed \(context) elapsed_ms=\(started.pretty.msSinceNow)", error: error, extraInfo: diagnostics)
            throw error
        }
    }

    private func mediator(of account: ChainKit.Account) -> Mediator {
        client.blockchain.getMediator(network: account.chain.network.type)
    }

    private func fee(of payload: Payload, account: ChainKit.Account, mediator: Mediator) async throws -> Fee {
        let result: ChainRes<Fee>
        do {
            result = try await mediator.operation.calculateFee(payload: payload, account: account, priority: .standard)
        } catch {
            throw ChainKitOperationError.feeUnavailable(payloadId: payload.id, reason: error.logDescription)
        }
        guard let fee = result.getOrNull() else {
            if Self.isInsufficientFunds(result.error) { throw ChainKitOperationError.insufficientFunds(payloadId: payload.id) }
            throw ChainKitOperationError.feeUnavailable(payloadId: payload.id, reason: result.error?.logValue ?? "unknown")
        }
        return fee
    }

    /// The fee path wraps a node failure in `ChainError.Unknown`.
    static func isInsufficientFunds(_ error: KotlinThrowable?) -> Bool {
        switch error {
        case is ChainError.InsufficientFunds, is NodeError.InsufficientFunds: true
        case let unknown as ChainError.Unknown: isInsufficientFunds(unknown.cause)
        default: false
        }
    }

    private func nonce(of account: ChainKit.Account, mediator: Mediator) async throws -> BignumBigInteger {
        if let readNonce {
            return try await readNonce(account)
        }
        let result: NodeRes<BignumBigInteger>
        do {
            result = try await mediator.account.estimateNonce(account: account)
        } catch {
            throw ChainKitOperationError.nonceUnavailable(error.logDescription)
        }
        guard let nonce = result.getOrNull() else {
            throw ChainKitOperationError.nonceUnavailable(
                result.error?.logValue ?? "unknown",
                kind: ChainKitErrorKindClassifier.kind(nodeError: result.error)
            )
        }
        return nonce
    }

    private func sign(
        _ payload: Payload,
        account: ChainKit.Account,
        fee: Fee,
        nonce: BignumBigInteger,
        wallet: MnemonicWallet,
        mediator: Mediator
    ) async throws -> SignedPayload {
        let result: SignRes<SignedPayload>
        do {
            result = try await mediator.operation.sign(payload: payload, account: account, fee: fee, nonce: nonce, wallet: wallet)
        } catch {
            throw ChainKitOperationError.signingFailed(payloadId: payload.id, reason: error.logDescription)
        }
        guard let signed = result.getOrNull() else {
            throw ChainKitOperationError.signingFailed(
                payloadId: payload.id,
                reason: result.error?.logValue ?? "unknown",
                kind: ChainKitErrorKindClassifier.kind(signError: result.error)
            )
        }
        return signed
    }

    /// A failed lookup is retried like a pending one: only the timeout gives up.
    private func waitForConfirmation(of hash: String, account: ChainKit.Account, mediator: Mediator, expiresAt: Date) async throws {
        let deadline = min(expiresAt, Date().addingTimeInterval(Self.confirmationTimeout))
        while Date() < deadline {
            try Task.checkCancellation()
            let status = try? await mediator.transaction.findTransaction(account: account, hash: hash, blockNumber: Self.noBlock).getOrNull()?.status
            if status is TransactionInfoStatusConfirmed { return }
            if let failed = status as? TransactionInfoStatusFailed {
                throw ChainKitOperationError.signingFailed(payloadId: hash, reason: "previous transaction failed: \(failed.error)")
            }
            try await Task.sleep(nanoseconds: Self.confirmationPollNanoseconds)
        }
        try Self.checkDeadline(expiresAt)
        throw ChainKitOperationError.feeUnavailable(payloadId: hash, reason: "previous transaction not confirmed")
    }
}
