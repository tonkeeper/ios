import BigInt
import ChainKit
import Foundation
import TKLogging

enum PerpsFundingDeliveryError: Error, Equatable {
    case unlockFailed(String)
}

extension PerpsFundingDeliveryError: LoggableError {
    var logDescription: String {
        String(describing: self)
    }
}

protocol PerpsDepositDelivery {
    /// What the operation costs on its chain, in that chain's own coin, or `nil` when a payload
    /// cannot be priced before an earlier one is on chain. No keys: the review screen asks
    /// before the user has agreed to anything.
    func networkFeeUnits(of operation: PerpsDepositOperation, on chain: MultichainChain) async -> BigUInt?

    func walletNetworkFeeUnits(of operation: PerpsDepositOperation, on chain: MultichainChain) async -> [String: BigUInt]

    func tronBandwidthFeeUnits() async -> BigUInt?

    func bitcoinBytePrice(paying units: BigUInt, from sender: String) async -> BigUInt?

    /// The account of `asset`, the chain's own coin when `nil`, at `sender`: the address the
    /// operation was quoted for. No keys, so a review reads the same account before the unlock as after it.
    func account(of asset: PerpsFundingAsset?, on chain: MultichainChain, sender: String) throws -> ChainKit.Account

    /// One unlock. The derived keys live in the returned session and nowhere else.
    func broadcastLegacy(_ step: PerpsPendingL1Step, on chain: MultichainChain, expiresAt: Date?) async throws
    func broadcast(_ transmission: PerpsDepositTransmission, on chain: MultichainChain, persist: (ChainKitSignedTransaction) async throws -> Void) async throws
    func openSession(passcode: String) async throws -> any PerpsDepositSigningSession
}

protocol PerpsDepositSigningSession {
    /// Signs and broadcasts every payload in order from `sender`, the address the operation was
    /// quoted for; the hashes in the same order.
    func send(_ operation: PerpsDepositOperation, on chain: MultichainChain, sender: String, expiresAt: Date, saved: [ChainKitSignedTransaction], persist: (ChainKitSignedTransaction) async throws -> Void) async throws -> [String]
    /// Signs an operation of documents only, with the Ethereum key of `owner`: ChainKit's signed
    /// payloads by id, as JSON.
    func signDocuments(_ operation: PerpsDepositOperation, owner: String) async throws -> [String: String]
}

struct PerpsChainKitDepositDelivery: PerpsDepositDelivery {
    private let sender: ChainKitOperationSender
    private let mnemonicAccess: MnemonicAccess
    private let wallet: Wallet

    init(client: CryptoKitClient, mnemonicAccess: MnemonicAccess, wallet: Wallet) {
        sender = ChainKitOperationSender(client: client)
        self.mnemonicAccess = mnemonicAccess
        self.wallet = wallet
    }

    func networkFeeUnits(of operation: PerpsDepositOperation, on chain: MultichainChain) async -> BigUInt? {
        let parsed: ChainKit.Operation
        let account: ChainKit.Account
        do {
            parsed = try operation.parsed()
            account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
        } catch {
            PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "wallet", error: error, fields: ["chain": chain.rawValue])
            return nil
        }
        var total = BigUInt(0)
        for fee in await sender.fees(of: parsed, account: account) {
            guard let fee, let amount = BigUInt(fee.amount.description) else {
                PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "chain_rpc", fields: ["chain": chain.rawValue, "reason": "fee_not_priced"])
                return nil
            }
            total += amount
        }
        return total
    }

    func walletNetworkFeeUnits(of operation: PerpsDepositOperation, on chain: MultichainChain) async -> [String: BigUInt] {
        let unpriced: ChainKit.Operation
        let account: ChainKit.Account
        do {
            let parsed = try operation.parsed()
            unpriced = ChainKit.Operation.Companion.shared.build(id: parsed.id, payloads: parsed.payloads.filter { $0.fee != nil }.map {
                $0.doCopy(id: $0.id, type: $0.type, chain: $0.chain, version: $0.version, fee: nil, meta: $0.meta)
            })
            account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
        } catch {
            PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "wallet", error: error, fields: ["chain": chain.rawValue, "reason": "wallet_estimate"])
            return [:]
        }
        let coinId = account.chain.toAsset().id
        var units = [String: BigUInt]()
        for (payload, fee) in zip(unpriced.payloads, await sender.fees(of: unpriced, account: account)) {
            guard let fee, fee.asset.id == coinId, let amount = BigUInt(fee.amount.description) else {
                PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "chain_rpc", fields: ["chain": chain.rawValue, "payload_id": payload.id, "reason": "wallet_estimate"])
                continue
            }
            units[payload.id] = amount
        }
        return units
    }

    func tronBandwidthFeeUnits() async -> BigUInt? {
        let units: BigUInt?
        do {
            let account = try ChainKitOperationSender.account(wallet: wallet, chain: .tron)
            let payload = ChainKit.Payload(
                id: "tron_bandwidth",
                type: .main,
                chain: account.chain,
                version: ChainKit.Payload.Companion.shared.VERSION,
                fee: nil,
                meta: PayloadMetaTronMain(
                    to: account.address,
                    value: BignumBigInteger.Companion.shared.parseString(string: "0", base: 10),
                    data: nil,
                    memo: nil
                )
            )
            let operation = ChainKit.Operation.Companion.shared.build(id: "tron_bandwidth", payloads: [payload])
            let fee = await sender.fees(of: operation, account: account).first ?? nil
            units = fee.flatMap { BigUInt($0.amount.description) }
        } catch {
            PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "wallet", error: error, fields: ["chain": MultichainChain.tron.rawValue, "reason": "bandwidth"])
            return nil
        }
        PerpsOperationLog.event("network_fee", outcome: units == nil ? "unavailable" : "bandwidth", source: "chain_rpc", fields: ["chain": MultichainChain.tron.rawValue, "bandwidth_units": units?.description ?? "none"])
        return units
    }

    func bitcoinBytePrice(paying units: BigUInt, from sender: String) async -> BigUInt? {
        let price: BigUInt?
        do {
            let account = try account(of: nil, on: .btc, sender: sender)
            let payload = ChainKit.Payload(
                id: "bitcoin_byte_price",
                type: .main,
                chain: account.chain,
                version: ChainKit.Payload.Companion.shared.VERSION,
                fee: nil,
                meta: PayloadMetaBitcoinMain(
                    to: account.address,
                    value: BignumBigInteger.Companion.shared.parseString(string: units.description, base: 10),
                    memo: nil
                )
            )
            let operation = ChainKit.Operation.Companion.shared.build(id: "bitcoin_byte_price", payloads: [payload])
            let fee = await self.sender.fees(of: operation, account: account).first ?? nil
            price = (fee as? FeeGas).flatMap { BigUInt($0.price.description, radix: 10) }
        } catch {
            PerpsOperationLog.event("network_fee", outcome: "unavailable", source: "wallet", error: error, fields: ["chain": MultichainChain.btc.rawValue, "reason": "byte_price"])
            return nil
        }
        PerpsOperationLog.event("network_fee", outcome: price == nil ? "unavailable" : "byte_price", source: "chain_rpc", fields: ["chain": MultichainChain.btc.rawValue, "byte_price": price?.description ?? "none"])
        return price
    }

    func account(of asset: PerpsFundingAsset?, on chain: MultichainChain, sender: String) throws -> ChainKit.Account {
        let account = try ChainKitOperationSender.account(wallet: wallet, chain: chain, holding: asset.map {
            MultichainAssetDetails(assetId: $0.assetId, name: $0.symbol, symbol: $0.symbol, decimals: $0.decimals, image: "")
        })
        guard PerpsFundingAssetId.sameAddress(account.addressDisplay, sender) else {
            throw ChainKitOperationError.keyMismatch(expected: sender, unlocked: account.addressDisplay)
        }
        return account
    }

    func broadcastLegacy(_ step: PerpsPendingL1Step, on chain: MultichainChain, expiresAt: Date?) async throws {
        let account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
        guard PerpsFundingAssetId.sameAddress(account.addressDisplay, step.sender) else {
            throw ChainKitOperationError.keyMismatch(expected: step.sender, unlocked: account.addressDisplay)
        }
        if step.state == .accepted { return }
        let mediator = sender.client.blockchain.getMediator(network: account.chain.network.type)
        let zero = BignumBigInteger.Companion.shared.parseString(string: "0", base: 10)
        if let found = try await mediator.transaction.findTransaction(account: account, hash: step.txHash, blockNumber: zero).getOrNull() {
            if found.status is TransactionInfoStatusConfirmed || found.status is TransactionInfoStatusPending { return }
        }
        if let deadline = step.validUntil, Date().timeIntervalSince1970 >= Double(deadline) {
            throw ChainKitOperationError.quoteExpired
        }
        if let expiresAt { try ChainKitOperationSender.checkDeadline(expiresAt) }
        let raw: String
        if chain == .ton {
            guard let bytes = Data(base64Encoded: step.signedTransaction) else {
                throw ChainKitOperationError.malformed(step.stepId)
            }
            raw = bytes.map { String(format: "%02x", $0) }.joined()
        } else {
            raw = step.signedTransaction
        }
        let result = try await mediator.transaction.sendRawTransaction(account: account, transaction: raw)
        guard let hash = result.getOrNull(), PerpsFundingAssetId.sameAddress(hash as String, step.txHash) else {
            throw ChainKitOperationError.broadcastFailed(payloadId: step.stepId, sent: [], reason: result.error?.logValue ?? "hash mismatch")
        }
    }

    func broadcast(_ transmission: PerpsDepositTransmission, on chain: MultichainChain, persist: (ChainKitSignedTransaction) async throws -> Void) async throws {
        let account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
        guard PerpsFundingAssetId.sameAddress(account.addressDisplay, transmission.sender) else {
            throw ChainKitOperationError.keyMismatch(expected: transmission.sender, unlocked: account.addressDisplay)
        }
        let operation = try transmission.operation.parsed()
        for var step in transmission.steps where !step.acknowledged {
            guard let payload = operation.payloads.first(where: { $0.id == step.payloadId }) else {
                throw ChainKitOperationError.malformed(step.payloadId)
            }
            try await ChainKitOperationSender.prepareBroadcast(&step, expiresAt: transmission.expiresAt, persist: persist)
            step.hash = try await sender.broadcast(step, payload: payload, account: account)
            step.acknowledged = true
            try await persist(step)
        }
    }

    func openSession(passcode: String) async throws -> any PerpsDepositSigningSession {
        let words: [String]
        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
            switch mnemonic.type {
            case .bip39:
                break
            case .bip39soft:
                throw PerpsFundingDeliveryError.unlockFailed("recovery phrase checksum invalid")
            case .ton, .unknown:
                throw PerpsFundingDeliveryError.unlockFailed("wallet mnemonic is not BIP39")
            }
            words = mnemonic.mnemonicWords
        } catch let error as PerpsFundingDeliveryError {
            throw error
        } catch {
            throw PerpsFundingDeliveryError.unlockFailed(error.logDescription)
        }
        do {
            let phrase = words.flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return try Session(
                sender: sender,
                wallet: wallet,
                cryptoWallet: CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase.joined(separator: " "))
            )
        } catch {
            throw PerpsFundingDeliveryError.unlockFailed(error.logDescription)
        }
    }

    private struct Session: PerpsDepositSigningSession {
        let sender: ChainKitOperationSender
        let wallet: Wallet
        let cryptoWallet: MnemonicWallet

        var registrationAddress: String {
            cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display
        }

        func send(_ operation: PerpsDepositOperation, on chain: MultichainChain, sender quoted: String, expiresAt: Date, saved: [ChainKitSignedTransaction], persist: (ChainKitSignedTransaction) async throws -> Void) async throws -> [String] {
            let account = try ChainKitOperationSender.account(wallet: wallet, chain: chain)
            guard PerpsFundingAssetId.sameAddress(account.addressDisplay, quoted) else {
                throw ChainKitOperationError.keyMismatch(expected: quoted, unlocked: account.addressDisplay)
            }
            return try await sender.send(operation.parsed(), account: account, wallet: cryptoWallet, expiresAt: expiresAt, fees: [], saved: saved, persist: persist)
        }

        func signDocuments(_ operation: PerpsDepositOperation, owner: String) async throws -> [String: String] {
            let account = try ChainKitOperationSender.account(wallet: wallet, chain: .eth)
            guard PerpsFundingAssetId.sameAddress(account.addressDisplay, owner),
                  PerpsFundingAssetId.sameAddress(registrationAddress, owner)
            else {
                throw ChainKitOperationError.keyMismatch(expected: owner, unlocked: registrationAddress)
            }
            return try await sender.signDocuments(operation.parsed(), account: account, wallet: cryptoWallet)
        }
    }
}
