import BigInt
import ChainKit
import Foundation
import OpenAPIRuntime
import TKBatteryAPI
import TonSwift

/// What the relayer is asked to carry for an EVM or Solana transfer: one call of the sender's, described
/// the way `/gasless/estimate` and `/gasless/emulate` take it.
struct EVMGaslessCall: Hashable, Sendable {
    /// The operation type the call serves, echoed back by the relayer in `operation.type`.
    enum Kind: String, Sendable {
        case transfer
        case swap
    }

    let kind: Kind
    /// The relayer's own spelling of the chain, `eth/mainnet`.
    let chainId: String
    let sender: String
    let to: String
    let value: BigUInt
    /// Calldata as hex; `0x` for a plain coin transfer and on Solana.
    let data: String
    /// Solana: the SPL mint a token transfer moves; `nil` for SOL and on the EVM chains.
    var token: String? = nil
    /// Solana: the text the Memo program writes; on the EVM chains a memo goes into `data`.
    var memo: String? = nil
    /// Solana: a route's own transaction, base64, which the relayer takes as built and pays for.
    var transaction: String? = nil

    static let emptyData = "0x"
    static let payloadId = "p_01"
    static let payloadType = "main"
    static let prebuildPayloadType = "prebuild"

    /// The call that moves `amount` of `assetId` from `sender` to `recipient`: the coin's own value
    /// transfer, or an ERC-20 `transfer` on the token's contract. `nil` for what the relayer cannot
    /// carry — an asset off the EVM chains and Solana, a token standard other than ERC-20/BEP-20 or
    /// SPL, or an EVM recipient that is not a 20-byte hex address. `memo` goes where ChainKit signs
    /// it: into an EVM coin transfer's calldata, nowhere for an EVM token, and to the Memo program on Solana.
    static func transfer(
        chain: MultichainChain,
        sender: String,
        assetId: String,
        recipient: String,
        amount: BigUInt,
        memo: String? = nil
    ) -> EVMGaslessCall? {
        if chain == .sol {
            return solanaTransfer(sender: sender, assetId: assetId, recipient: recipient, amount: amount, memo: memo)
        }
        guard chain.isEVM, let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }
        switch components {
        case .coin:
            guard isAddress(recipient) else {
                return nil
            }
            return EVMGaslessCall(
                kind: .transfer,
                chainId: chain.relayerChainId,
                sender: sender,
                to: recipient,
                value: amount,
                data: memo.map { "0x" + Data($0.utf8).hexString() } ?? emptyData
            )
        case let .asset(_, _, type, contract):
            guard tokenTypes.contains(type.lowercased()),
                  let data = erc20TransferData(recipient: recipient, amount: amount)
            else {
                return nil
            }
            return EVMGaslessCall(
                kind: .transfer,
                chainId: chain.relayerChainId,
                sender: sender,
                to: contract,
                value: 0,
                data: data
            )
        }
    }

    /// The route's call of a swap. With calldata it is that call as it stands, `amount` being the
    /// coin sent along with it; without, the route collects a deposit, and the call is a transfer
    /// of `amount` of `assetId` to its address — either way under the swap kind.
    static func swap(
        chain: MultichainChain,
        sender: String,
        assetId: String,
        to: String,
        amount: BigUInt,
        data: String?
    ) -> EVMGaslessCall? {
        guard let data, !data.isEmpty, data != emptyData else {
            guard let transfer = transfer(chain: chain, sender: sender, assetId: assetId, recipient: to, amount: amount) else {
                return nil
            }
            return EVMGaslessCall(
                kind: .swap,
                chainId: transfer.chainId,
                sender: transfer.sender,
                to: transfer.to,
                value: transfer.value,
                data: transfer.data,
                token: transfer.token,
                memo: transfer.memo
            )
        }
        guard chain.isEVM, isAddress(to) else {
            return nil
        }
        return EVMGaslessCall(
            kind: .swap,
            chainId: chain.relayerChainId,
            sender: sender,
            to: to,
            value: amount,
            data: data
        )
    }

    /// A Solana route's own transaction, which the relayer is asked to carry as the route built it.
    static func solanaSwap(sender: String, transaction: String) -> EVMGaslessCall {
        EVMGaslessCall(
            kind: .swap,
            chainId: MultichainChain.sol.relayerChainId,
            sender: sender,
            to: "",
            value: 0,
            data: emptyData,
            transaction: transaction
        )
    }

    private static func solanaTransfer(
        sender: String,
        assetId: String,
        recipient: String,
        amount: BigUInt,
        memo: String?
    ) -> EVMGaslessCall? {
        let token: String?
        switch AssetIdComponents(assetId: assetId) {
        case .coin?:
            token = nil
        case let .asset(_, _, type, mint)? where type.lowercased() == solanaTokenType:
            token = mint
        default:
            return nil
        }
        return EVMGaslessCall(
            kind: .transfer,
            chainId: MultichainChain.sol.relayerChainId,
            sender: sender,
            to: recipient,
            value: amount,
            data: emptyData,
            token: token,
            memo: memo?.isEmpty == false ? memo : nil
        )
    }

    /// `transfer(address,uint256)` calldata: the selector, then both arguments as 32-byte words.
    static func erc20TransferData(recipient: String, amount: BigUInt) -> String? {
        guard let address = hexAddress(recipient) else {
            return nil
        }
        let value = String(amount, radix: 16)
        guard value.count <= wordHexLength else {
            return nil
        }
        return "0x" + transferSelector + word(address) + word(value)
    }

    static func isAddress(_ value: String) -> Bool {
        hexAddress(value) != nil
    }

    /// The unsigned payload the relayer prices and emulates; `id` tells the calls of one batch apart.
    func payload(id: String = payloadId) throws -> Components.Schemas.GaslessV2Payload {
        try Components.Schemas.GaslessV2Payload(
            id: id,
            _type: transaction == nil ? Self.payloadType : Self.prebuildPayloadType,
            chain_id: chainId,
            version: Int(ChainKit.Payload.Companion.shared.VERSION),
            meta: .init(additionalProperties: OpenAPIObjectContainer(unvalidatedValue: meta))
        )
    }

    /// The payload's meta: an EVM call, a Solana transfer as ChainKit's `PayloadMetaSolanaMain` reads it,
    /// or a Solana route's transaction as its `PayloadMetaSolanaPrebuild` does.
    private var meta: [String: (any Sendable)?] {
        guard chainId == MultichainChain.sol.relayerChainId else {
            return ["to": to, "value": value.description, "data": data]
        }
        if let transaction {
            return ["data": transaction]
        }
        var meta: [String: (any Sendable)?] = ["to": to, "value": value.description]
        if let token {
            meta["token"] = token
        }
        if let memo {
            meta["memo"] = memo
        }
        return meta
    }

    private static let tokenTypes: Set<String> = ["erc20", "bep20"]
    private static let solanaTokenType = "spl"
    private static let transferSelector = "a9059cbb"
    private static let wordHexLength = 64
    private static let addressHexLength = 40

    /// The 40 lowercase hex digits of a 20-byte address, or nil for anything else.
    private static func hexAddress(_ value: String) -> String? {
        var address = value.lowercased()
        if address.hasPrefix("0x") {
            address.removeFirst(2)
        }
        guard address.count == addressHexLength, address.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return address
    }

    private static func word(_ hex: String) -> String {
        String(repeating: "0", count: wordHexLength - hex.count) + hex
    }
}
