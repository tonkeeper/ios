import BigInt
import ChainKit
import Foundation
import TKLogging

struct MultichainSwapPayloadAdapter {
    struct Normalized {
        /// One per message of the payload, in envelope order: Omniston splits a larger TON swap
        /// across pools and every part has to leave in the same wallet transaction.
        let transactions: [TransactionSwap]
        let account: ChainKit.Account
        let feeAsset: AssetCoin
        let fee: (any Fee)?
        let approvalData: String?
        let sourceChain: MultichainChain
        let networkType: ChainKit.Network.Type_
        /// The payload in the shape a battery fee method would send it; `nil` leaves it payable in
        /// its own chain's coin only.
        let batteryPayload: MultichainSwapBatteryPayload?
        /// Whether the amount may still move after the quote. `exact` calldata carries the sell
        /// amount inside it, so the transaction has to leave with exactly that amount.
        let calldataType: MultichainSwapCalldataPayloadType

        var isExactCalldata: Bool {
            calldataType == .exact
        }

        /// Exact calldata is never trimmed to make room for the fee: a wallet that cannot cover
        /// both is short, and says so, rather than sending an amount the calldata no longer matches.
        /// Neither is a split route, whose parts were quoted as one amount.
        var gasReservePolicy: GasReservePolicy {
            isExactCalldata || transactions.count > 1 ? .drainorerror : .shrinktofit
        }

        var attachedEnergy: BignumBigInteger {
            transactions.reduce(BignumBigInteger.Companion.shared.ZERO) { total, transaction in
                total.add(other: transaction.attachedEnergy)
            }
        }
    }

    func normalize(
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payload: MultichainSwapPreparedPayload,
        provider: MultichainSwapProvider,
        sourcePublicKey: PubKey? = nil,
        destinationPublicKey: PubKey? = nil
    ) throws(MultichainSwapExecutionFailure) -> Normalized {
        Log.multichainSwap.i(
            "payload normalization started",
            extraInfo: payloadLogInfo(
                payload,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset
            )
        )
        guard let sourceChain = sourceAsset.asset.chain else {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "source asset has no chain: \(sourceAsset.asset.assetId)"
            )
        }
        guard let destinationChain = destinationAsset.asset.chain else {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "destination asset has no chain: \(destinationAsset.asset.assetId)"
            )
        }
        if let payloadChain = MultichainChain(crossSwapChainId: payload.chainId),
           payloadChain != sourceChain
        {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "payload chain \(payload.chainId) does not match source chain \(sourceChain.rawValue)"
            )
        }

        guard let sourceChainAsset = chainKitAsset(asset: sourceAsset) else {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "unsupported source asset \(sourceAsset.asset.assetId)"
            )
        }
        guard let destinationChainAsset = chainKitAsset(asset: destinationAsset) else {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "unsupported destination asset \(destinationAsset.asset.assetId)"
            )
        }

        let sourceWalletAddress = try walletAddress(
            swapWallet: swapWallet,
            chain: sourceChain,
            payloadId: payload.payloadId
        )
        let destinationWalletAddress = try walletAddress(
            swapWallet: swapWallet,
            chain: destinationChain,
            payloadId: payload.payloadId
        )

        let sourceAddress = try chainKitAddress(
            sourceWalletAddress.address,
            chain: sourceChain,
            type: senderAddressType(sourceWalletAddress),
            payloadId: payload.payloadId,
            role: "source"
        )
        let destinationAddress = try chainKitAddress(
            destinationWalletAddress.address,
            chain: destinationChain,
            type: .default_,
            payloadId: payload.payloadId,
            role: "destination"
        )

        let account = ChainKit.Account(
            address: sourceAddress,
            asset: sourceChainAsset,
            derivation: DerivationDefaultPath.shared,
            publicKey: sourcePublicKey
        )
        let destination = ChainKit.Account(
            address: destinationAddress,
            asset: destinationChainAsset,
            derivation: DerivationDefaultPath.shared,
            publicKey: destinationPublicKey
        )
        let feeAsset = sourceChainAsset.chain.toAsset()
        let tradePayload = try tradePayload(
            payload,
            provider: provider,
            sourceChain: sourceChain
        )

        let transactions = tradePayload.messages.map { message in
            TransactionSwap(
                account: account,
                amount: BignumBigInteger.Companion.shared.parseString(
                    string: message.amount.description,
                    base: 10
                ),
                isMax: false,
                destination: destination,
                to: message.to,
                data: message.data,
                initData: nil,
                memo: nil
            )
        }

        Log.multichainSwap.i(
            "payload normalization completed",
            extraInfo: payloadLogInfo(
                payload,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: [
                    "sourceChain": sourceChain.rawValue,
                    "destinationChain": destinationChain.rawValue,
                    "feeAsset": feeAsset.id,
                    "messageCount": "\(transactions.count)",
                ]
            )
        )

        return Normalized(
            transactions: transactions,
            account: account,
            feeAsset: feeAsset,
            fee: tradePayload.fee,
            approvalData: tradePayload.approvalData,
            sourceChain: sourceChain,
            networkType: sourceChain.asChainKitChain.network.type,
            batteryPayload: batteryPayload(
                payload: payload,
                sourceAsset: sourceAsset,
                sourceChain: sourceChain,
                sender: sourceWalletAddress.address,
                tradePayload: tradePayload
            ),
            calldataType: tradePayload.calldataType
        )
    }
}

extension MultichainSwapPayloadAdapter {
    /// Everything a relayed TON message carries over from the envelope. The schema names the
    /// recipient, amount and body `address`, `amount` and `payload`; aggregators are also seen
    /// sending them as `to`, `value` and `data`.
    static let reproducibleTonMessageKeys: Set<String> = [
        "address", "to",
        "amount", "value",
        "payload", "data",
    ]

    /// The value of every message in a `ton_boc` envelope, or `nil` when it is not one this wallet
    /// can read. Both spellings of the amount key are accepted for the same reason
    /// `reproducibleTonMessageKeys` accepts both.
    static func tonMessageValues(_ payload: String) -> [BigUInt]? {
        guard let data = payload.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !messages.isEmpty
        else {
            return nil
        }
        let values = messages.compactMap { message -> BigUInt? in
            guard let raw = message["amount"] ?? message["value"] else {
                return nil
            }
            let text = (raw as? String) ?? (raw as? NSNumber)?.stringValue
            return text.flatMap { BigUInt($0) }
        }
        return values.count == messages.count ? values : nil
    }

    /// A deposit descriptor in the shape the source chain's ChainKit parser reads. SwapKit answers
    /// with the descriptor itself — `{"amount": …, "to": …}` — while every parser reads what
    /// swaps.xyz sends: TON an envelope of messages, an EVM chain a transaction whose amount is
    /// `value`. Neither refusal is partial, so a descriptor that is not translated leaves the route
    /// unusable rather than merely unrelayable.
    ///
    /// Only `alt_vm_deposit` may be translated, and only the caller knows the type: the schema fixes
    /// the shape of every other payload — a `ton_boc` envelope, an EVM transaction — and repairing
    /// one of those would hide a backend that broke its own contract. Anything already in shape, and
    /// anything that is not JSON at all, is handed back untouched.
    static func parsableDepositDescriptor(_ payload: String, chain: MultichainChain) -> String {
        guard let data = payload.data(using: .utf8),
              let descriptor = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return payload
        }
        switch chain {
        case .ton:
            return "[\(payload)]"
        case .eth, .base, .arb, .bsc, .polygon, .avax, .robinhood:
            guard descriptor["value"] == nil, let amount = descriptor["amount"] else {
                return payload
            }
            var transaction = descriptor
            transaction["value"] = amount
            guard let encoded = try? JSONSerialization.data(withJSONObject: transaction),
                  let text = String(data: encoded, encoding: .utf8)
            else {
                return payload
            }
            return text
        case .btc, .tron, .sol:
            return payload
        }
    }

    /// `nil` when every message of the `ton_boc` envelope is one this path can hand to a relayer
    /// unchanged; otherwise what stands in the way. A relayed swap is rebuilt from the parsed
    /// recipient, amount and body and nothing else, so anything further in the envelope — a state
    /// init, a send mode, a key we have never seen — would reach the chain as a different
    /// transaction than the quote described. ChainKit's parse exposes neither state init nor mode,
    /// so rather than guess at them the swap keeps the native path, which sends the BOC verbatim.
    static func tonRelayObstacle(_ payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return "envelope is not a list of messages"
        }
        guard !messages.isEmpty else {
            return "envelope holds no messages"
        }
        let carried = Set(messages.flatMap(\.keys)).filter { key in
            !reproducibleTonMessageKeys.contains(key.lowercased().replacingOccurrences(of: "_", with: ""))
        }
        guard !carried.isEmpty else {
            return nil
        }
        return "message carries \(carried.sorted().joined(separator: ", "))"
    }
}

private extension MultichainSwapPayloadAdapter {
    struct TradePayload {
        let messages: [TradeMessage]
        let approvalData: String?
        let fee: (any Fee)?
        let calldataType: MultichainSwapCalldataPayloadType
    }

    struct TradeMessage {
        let amount: BigUInt
        let to: Address
        let data: String?
    }

    func tradePayload(
        _ payload: MultichainSwapPreparedPayload,
        provider: MultichainSwapProvider,
        sourceChain: MultichainChain
    ) throws(MultichainSwapExecutionFailure) -> TradePayload {
        if case let .unsupported(rawValue) = payload.preparedPayloadType {
            throw .unsupportedPayloadType(rawValue)
        }

        let isApproval: Bool
        switch payload.payloadKind {
        case .approval:
            guard payload.preparedPayloadType == .evmApprovalTransaction else {
                throw .invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "approval payload must use evm_approval_tx, got \(payload.payloadType)"
                )
            }
            isApproval = true
        case .main:
            guard payload.preparedPayloadType != .evmApprovalTransaction else {
                throw .invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "main payload cannot use evm_approval_tx"
                )
            }
            isApproval = false
        case let .other(kind):
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "unsupported payload kind \(kind)"
            )
        }
        let calldataType = resolvedCalldataType(
            of: payload,
            isApproval: isApproval,
            provider: provider,
            sourceChain: sourceChain
        )
        let rawPayload = payload.preparedPayloadType == .altVmDeposit
            ? Self.parsableDepositDescriptor(payload.payload, chain: sourceChain)
            : payload.payload
        let envelope = try Self.envelopeMessages(rawPayload, chain: sourceChain, payloadId: payload.payloadId)
        let depositAddress = envelope.count == 1 ? payload.humanSummary.depositAddress?.nonEmpty : nil
        var parsedMessages = [SwapPayload]()
        for message in envelope {
            do {
                try parsedMessages.append(
                    SwapPayload.Companion.shared.fromQuote(
                        provider: provider.chainKitProvider,
                        type: calldataType.chainKitType,
                        chain: sourceChain.asChainKitChain,
                        payload: message,
                        depositAddress: depositAddress,
                        spendAmount: payload.humanSummary.spendAmount
                    )
                )
            } catch {
                throw .invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "\(provider.rawValue) payload is not parsable: \(error.logDescription)"
                )
            }
        }

        var messages = [TradeMessage]()
        for parsed in parsedMessages {
            guard let amount = BigUInt(parsed.amount.description) else {
                throw .invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "payload amount is not an unsigned integer: \(parsed.amount.description)"
                )
            }
            try messages.append(
                TradeMessage(
                    amount: amount,
                    to: chainKitAddress(
                        parsed.to,
                        chain: sourceChain,
                        type: .default_,
                        payloadId: payload.payloadId,
                        role: "\(provider.rawValue) to"
                    ),
                    data: isApproval ? nil : parsed.data
                )
            )
        }

        let single = parsedMessages.count == 1 ? parsedMessages.first : nil
        return TradePayload(
            messages: messages,
            approvalData: isApproval ? single?.data : nil,
            fee: single?.fee,
            calldataType: calldataType
        )
    }

    /// ChainKit's TON parser reads the first message of an envelope, so a split route is handed to
    /// it one message at a time. A part names its own recipient and amount: the deposit address and
    /// the spend amount describe the whole route, never one of its parts.
    static func envelopeMessages(
        _ payload: String,
        chain: MultichainChain,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) -> [String] {
        guard chain == .ton else {
            return [payload]
        }
        let messages: [Any]
        do {
            guard let envelope = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [Any],
                  envelope.count > 1
            else {
                return [payload]
            }
            messages = envelope
        } catch {
            Log.multichainSwap.w(
                "ton payload is not json",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            return [payload]
        }
        guard tonMessageValues(payload) != nil else {
            throw .invalidPayload(
                payloadId: payloadId,
                reason: "a message of a split envelope names no amount"
            )
        }
        var envelopes = [String]()
        for message in messages {
            do {
                let data = try JSONSerialization.data(withJSONObject: [message], options: .withoutEscapingSlashes)
                envelopes.append(String(decoding: data, as: UTF8.self))
            } catch {
                throw .invalidPayload(
                    payloadId: payloadId,
                    reason: "a message of a split envelope cannot be encoded: \(error.localizedDescription)"
                )
            }
        }
        return envelopes
    }

    /// Whether an `evm_tx` payload holds router calldata rather than a plain value transfer this
    /// path rebuilds itself. A payload it cannot read counts as carrying its own transaction.
    static func carriesEvmCalldata(_ payload: String) -> Bool {
        guard let data = payload.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return true
        }
        guard let calldata = message["data"] as? String else {
            return false
        }
        return !calldata.isEmpty && calldata.lowercased() != "0x"
    }

    /// The backend says per payload whether its calldata is `exact` or `flex`; without the field the
    /// wallet has to guess, and guessing `flex` for a payload that carries its own transaction is
    /// destructive — ChainKit refuses an EVM one outright, and replaces a BTC PSBT or a TRON raw
    /// transaction with a plain transfer to the deposit address. So only a payload this path builds
    /// itself is assumed flexible: a deposit descriptor, an EVM transaction with no calldata, or a
    /// swaps.xyz leg, whose route calldata has always been dropped in favour of the deposit address.
    func resolvedCalldataType(
        of payload: MultichainSwapPreparedPayload,
        isApproval: Bool,
        provider: MultichainSwapProvider,
        sourceChain: MultichainChain
    ) -> MultichainSwapCalldataPayloadType {
        if let calldataType = payload.calldataPayloadType {
            return calldataType
        }
        let fallback: MultichainSwapCalldataPayloadType = {
            guard !isApproval, sourceChain != .ton else {
                return .exact
            }
            switch payload.preparedPayloadType {
            case .altVmDeposit:
                return .flex
            case .evmTransaction:
                return provider == .swapXyz || !Self.carriesEvmCalldata(payload.payload) ? .flex : .exact
            case .utxoPSBT, .tronTransaction:
                return provider == .swapXyz ? .flex : .exact
            case .tonBOC, .solanaTransaction, .evmApprovalTransaction, .unsupported:
                return .exact
            }
        }()
        Log.multichainSwap.w(
            "payload has no calldata_payload_type, assuming \(fallback.rawValue)",
            extraInfo: [
                "payloadId": payload.payloadId,
                "kind": payload.kind,
                "payloadType": payload.payloadType,
                "sourceChain": sourceChain.rawValue,
                "provider": provider.rawValue,
            ]
        )
        return fallback
    }

    func batteryPayload(
        payload: MultichainSwapPreparedPayload,
        sourceAsset: MultichainAsset,
        sourceChain: MultichainChain,
        sender: String,
        tradePayload: TradePayload
    ) -> MultichainSwapBatteryPayload? {
        // An approval is never relayed on its own: the relayer carries the main call, and a route
        // that needs an approval keeps the wallet paying.
        guard payload.payloadKind == .main else {
            return nil
        }
        switch sourceChain {
        case .ton:
            if payload.preparedPayloadType == .altVmDeposit {
                guard MultichainSwapRelayedAsset(sourceAsset) == .tonJetton,
                      TonJettonSwapTransferFactory.jettonMasterAddress(sourceAsset: sourceAsset) != nil,
                      tradePayload.messages.count == 1,
                      let deposit = tradePayload.messages.first,
                      deposit.data == nil
                else {
                    return nil
                }
                return .tonJettonDeposit(
                    TonJettonSwapDeposit(
                        recipient: deposit.to.display,
                        amount: deposit.amount
                    )
                )
            }
            guard payload.preparedPayloadType == .tonBOC else {
                return nil
            }
            if let obstacle = Self.tonRelayObstacle(payload.payload) {
                Log.multichainSwap.i(
                    "battery ton swap not offered: message cannot be reproduced",
                    extraInfo: [
                        "payloadId": payload.payloadId,
                        "obstacle": obstacle,
                    ]
                )
                return nil
            }
            return .ton(
                tradePayload.messages.map { message in
                    TonSwapMessage(
                        to: message.to.display,
                        amount: message.amount,
                        payload: message.data,
                        stateInit: nil
                    )
                }
            )
        case .tron:
            // A relayer signs its own TRON transaction, so only a payload that carries no call data
            // can be rebuilt from the route: anything else would have to be replayed verbatim.
            guard tradePayload.messages.count == 1,
                  let transfer = tradePayload.messages.first,
                  transfer.data == nil
            else {
                return nil
            }
            return .tron(
                TronSwapTransfer(to: transfer.to.display, amount: transfer.amount)
            )
        case .eth, .base, .arb, .bsc, .polygon, .avax, .robinhood:
            // The relayer's estimate prices one call: the route's, exactly as it was quoted.
            guard tradePayload.messages.count == 1,
                  let message = tradePayload.messages.first,
                  let call = EVMGaslessCall.swap(
                      chain: sourceChain,
                      sender: sender,
                      assetId: sourceAsset.asset.assetId,
                      to: message.to.display,
                      amount: message.amount,
                      data: message.data
                  )
            else {
                return nil
            }
            return .evm(EVMSwapRelay(chain: sourceChain, call: call))
        case .btc, .sol:
            return nil
        }
    }

    func walletAddress(
        swapWallet: MultichainSwapWallet,
        chain: MultichainChain,
        payloadId _: String
    ) throws(MultichainSwapExecutionFailure) -> MultichainWalletAddress {
        guard let address = swapWallet.walletAddress(for: chain) else {
            throw .missingWalletAddress(chain: chain)
        }
        return address
    }

    func senderAddressType(_ walletAddress: MultichainWalletAddress) -> Address.Type_ {
        switch walletAddress.chain {
        case .ton:
            walletAddress.type?.chainKitAddressType ?? .default_
        case .eth, .base, .btc, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
            .default_
        }
    }

    func chainKitAddress(
        _ string: String,
        chain: MultichainChain,
        type: Address.Type_,
        payloadId: String,
        role: String
    ) throws(MultichainSwapExecutionFailure) -> Address {
        guard let address = Address.Companion.shared.from(
            value: string,
            chain: chain.asChainKitChain,
            type: type
        ) else {
            throw .invalidPayload(
                payloadId: payloadId,
                reason: "invalid \(role) address \(string)"
            )
        }
        return address
    }
}

private extension MultichainSwapProvider {
    var chainKitProvider: SwapPayload.Provider {
        switch self {
        case .swapKit:
            return .swapkit
        case .swapXyz:
            return .swapxyz
        }
    }
}

private extension MultichainSwapCalldataPayloadType {
    var chainKitType: SwapPayload.Type_ {
        switch self {
        case .exact:
            return .exact
        case .flex:
            return .flex
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension MultichainChain {
    init?(crossSwapChainId: String) {
        guard let chain = crossSwapChainId.split(separator: "/").first else {
            return nil
        }
        self.init(assetIdChain: String(chain))
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
