import BigInt
import ChainKit
import Foundation
import TKLogging

struct MultichainSwapPayloadAdapter {
    struct Normalized {
        let transaction: TransactionSwap
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
        var gasReservePolicy: GasReservePolicy {
            isExactCalldata ? .drainorerror : .shrinktofit
        }
    }

    func normalize(
        wallet: Wallet,
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

        let sourceAddressString = try walletAddress(
            wallet: wallet,
            chain: sourceChain,
            payloadId: payload.payloadId
        )
        let destinationAddressString = try walletAddress(
            wallet: wallet,
            chain: destinationChain,
            payloadId: payload.payloadId
        )

        let sourceAddress = try chainKitAddress(
            sourceAddressString,
            chain: sourceChain,
            payloadId: payload.payloadId,
            role: "source"
        )
        let destinationAddress = try chainKitAddress(
            destinationAddressString,
            chain: destinationChain,
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

        let transaction = TransactionSwap(
            account: account,
            amount: BignumBigInteger.Companion.shared.parseString(
                string: tradePayload.amount.description,
                base: 10
            ),
            energy: feeAsset,
            isMax: false,
            destination: destination,
            to: tradePayload.to,
            data: tradePayload.data,
            initData: nil
        )

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
                ]
            )
        )

        return Normalized(
            transaction: transaction,
            feeAsset: feeAsset,
            fee: tradePayload.fee,
            approvalData: tradePayload.approvalData,
            sourceChain: sourceChain,
            networkType: sourceChain.asChainKitChain.network.type,
            batteryPayload: batteryPayload(
                payload: payload,
                sourceAsset: sourceAsset,
                sourceChain: sourceChain,
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
        case .eth, .base, .arb, .bsc:
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
        case .btc, .tron:
            return payload
        }
    }

    /// `nil` when the `ton_boc` envelope is one message this path can hand to a relayer unchanged;
    /// otherwise what stands in the way. A relayed swap is rebuilt from the parsed recipient, amount
    /// and body and nothing else, so anything further in the envelope — a state init, a send mode, a
    /// key we have never seen — would reach the chain as a different transaction than the quote
    /// described. ChainKit's parse exposes neither state init nor mode, so rather than guess at them
    /// the swap keeps the native path, which sends the BOC verbatim.
    static func tonRelayObstacle(_ payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return "envelope is not a list of messages"
        }
        guard messages.count == 1, let message = messages.first else {
            return "envelope holds \(messages.count) messages"
        }
        let carried = message.keys.filter { key in
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
        let amount: BigUInt
        let to: Address
        let data: String?
        let approvalData: String?
        let fee: (any Fee)?
        let calldataType: MultichainSwapCalldataPayloadType
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
            guard provider == .swapKit else {
                throw .invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "\(provider.rawValue) does not support approval payloads"
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
        let parsed: SwapPayload
        do {
            parsed = try SwapPayload.Companion.shared.fromQuote(
                provider: provider.chainKitProvider,
                type: calldataType.chainKitType,
                chain: sourceChain.asChainKitChain,
                payload: rawPayload,
                depositAddress: payload.humanSummary.depositAddress?.nonEmpty,
                spendAmount: payload.humanSummary.spendAmount
            )
        } catch {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "\(provider.rawValue) payload is not parsable: \(error.logDescription)"
            )
        }

        guard let amount = BigUInt(parsed.amount.description) else {
            throw .invalidPayload(
                payloadId: payload.payloadId,
                reason: "payload amount is not an unsigned integer: \(parsed.amount.description)"
            )
        }

        return try TradePayload(
            amount: amount,
            to: chainKitAddress(
                parsed.to,
                chain: sourceChain,
                payloadId: payload.payloadId,
                role: "\(provider.rawValue) to"
            ),
            data: isApproval ? nil : parsed.data,
            approvalData: isApproval ? parsed.data : nil,
            fee: parsed.fee,
            calldataType: calldataType
        )
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
            case .tonBOC, .evmApprovalTransaction, .unsupported:
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
        tradePayload: TradePayload
    ) -> MultichainSwapBatteryPayload? {
        switch sourceChain {
        case .ton:
            if payload.preparedPayloadType == .altVmDeposit {
                guard MultichainSwapRelayedAsset(sourceAsset) == .tonJetton,
                      TonJettonSwapTransferFactory.jettonMasterAddress(sourceAsset: sourceAsset) != nil,
                      tradePayload.data == nil
                else {
                    return nil
                }
                return .tonJettonDeposit(
                    TonJettonSwapDeposit(
                        recipient: tradePayload.to.display,
                        amount: tradePayload.amount
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
                TonSwapMessage(
                    to: tradePayload.to.display,
                    amount: tradePayload.amount,
                    payload: tradePayload.data,
                    stateInit: nil
                )
            )
        case .tron:
            // A relayer signs its own TRON transaction, so only a payload that carries no call data
            // can be rebuilt from the route: anything else would have to be replayed verbatim.
            guard tradePayload.data == nil else {
                return nil
            }
            return .tron(
                TronSwapTransfer(to: tradePayload.to.display, amount: tradePayload.amount)
            )
        case .btc, .eth, .base, .arb, .bsc:
            return nil
        }
    }

    func walletAddress(
        wallet: Wallet,
        chain: MultichainChain,
        payloadId: String
    ) throws(MultichainSwapExecutionFailure) -> String {
        guard case let .multichain(state) = wallet.multichain,
              let address = state.address(for: chain, preferredType: wallet.preferredMultichainAddressType(for: chain))
        else {
            throw .missingWalletAddress(chain: chain)
        }
        return address
    }

    func chainKitAddress(
        _ string: String,
        chain: MultichainChain,
        payloadId: String,
        role: String
    ) throws(MultichainSwapExecutionFailure) -> Address {
        guard let address = Address.Companion.shared.from(
            value: string,
            chain: chain.asChainKitChain,
            type: .default_
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
