import ChainKit
import Foundation
import TKPerpsAPI

/// The trading key named on each deposit quote (`change_pub_key`).
struct PerpsKeyRegistration: Sendable, Equatable {
    /// NIL_ACCOUNT_INDEX: changePubKey resolves it to the caller's own account when the call
    /// runs, and it is the only account a first deposit can name.
    static let ownAccountIndex: Int64 = 281_474_976_710_655
    /// `changePubKey(uint48,uint8,bytes)`.
    static let changePubKeySelector = "17010c68"

    let apiKeyIndex: Int
    /// `0x` and 40 bytes, lowercase.
    let publicKey: String

    init?(apiKeyIndex: Int, publicKey: String) {
        let lowercased = publicKey.lowercased()
        let hex = lowercased.hasPrefix("0x") ? String(lowercased.dropFirst(2)) : lowercased
        // 255 is Lighter's "all keys" sentinel, not a slot.
        guard (0 ... 254).contains(apiKeyIndex), PerpsKeyRegistrationPreview.isHex(hex, length: 80) else { return nil }
        self.apiKeyIndex = apiKeyIndex
        self.publicKey = "0x" + hex
    }

    func request() -> Components.Schemas.ChangePubKey {
        .init(account_index: Self.ownAccountIndex, api_key_index: apiKeyIndex, pub_key: publicKey)
    }

    /// The call into Lighter's gateway that registers the key, as the owner makes it.
    var calldata: String {
        func word(_ value: Int64) -> String {
            let hex = String(value, radix: 16)
            return String(repeating: "0", count: 64 - hex.count) + hex
        }
        return "0x" + Self.changePubKeySelector
            + word(Self.ownAccountIndex) + word(Int64(apiKeyIndex)) + word(0x60) + word(40)
            + publicKey.dropFirst(2) + String(repeating: "0", count: 48)
    }
}

/// A quote that registers the key on a route the aggregator fills: priced as the deposit will
/// be, with nothing to send yet. Its operation is what the owner signs ahead — the delegate's
/// `Execute` over the one `changePubKey` call and the EIP-7702 delegation to HermesDelegateV1
/// it runs under — which goes back with the same request for the quote that is sent. Paid from
/// Ethereum, that quote's payment carries the delegation instead, so the preview is `Execute` alone.
struct PerpsKeyRegistrationPreview: Sendable, Equatable {
    let quoteId: String
    let expiresAt: Date
    let sourceAsset: PerpsFundingAssetId
    let sourceAmountUnits: String
    let sender: String
    let beneficiary: String
    let depositAmountUnits: String
    let registration: PerpsKeyRegistration
    let operation: PerpsDepositOperation
    let delegationPayloadId: String?
    let executePayloadId: String

    /// The preview's operation, signed, as the next quote takes it beside the registration.
    /// `signed` is ChainKit's signed payloads by id, each as the JSON it writes — that JSON is
    /// the shared signed-payload format, so it goes on as it is once the signatures are checked.
    func signedOperation(_ signed: [String: String]) throws(PerpsDepositQuoteError) -> Components.Schemas.SignedOperation {
        struct Envelope<Data: Decodable>: Decodable {
            struct Meta: Decodable {
                let data: Data
            }

            let payload_id: String
            let meta: Meta
        }
        struct Authorization: Decodable {
            let y_parity: Int
            let r: String
            let s: String
        }
        typealias SignedPayload = Components.Schemas.SignedPayload
        func decode<T: Decodable>(_: T.Type, payloadId: String) -> (data: T, payload: SignedPayload)? {
            guard let text = signed[payloadId].map({ Data($0.utf8) }),
                  let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: text),
                  envelope.payload_id == payloadId,
                  var payload = try? JSONDecoder().decode(SignedPayload.self, from: text)
            else { return nil }
            // ChainKit's signed payload carries no `version`, which the backend requires: it is the
            // request payload's, and `readPreview` takes only version 1.
            if payload.value["version"] == nil {
                var value = payload.value
                value["version"] = 1
                guard let versioned = try? SignedPayload(unvalidatedValue: value) else { return nil }
                payload = versioned
            }
            return (envelope.meta.data, payload)
        }
        var payloads = [SignedPayload]()
        if let delegationPayloadId {
            guard let authorization = decode(Authorization.self, payloadId: delegationPayloadId),
                  (0 ... 1).contains(authorization.data.y_parity),
                  Self.isHex(authorization.data.r, length: 64, prefixed: true),
                  Self.isHex(authorization.data.s, length: 64, prefixed: true)
            else {
                throw .malformedKeyRegistration("authorization signature")
            }
            payloads.append(authorization.payload)
        }
        guard let execute = decode(String.self, payloadId: executePayloadId),
              Self.isHex(execute.data, length: 130, prefixed: true)
        else {
            throw .malformedKeyRegistration("execute signature")
        }
        return .init(id: operation.id, payloads: payloads + [execute.payload])
    }

    static func isHex(_ value: String, length: Int, prefixed: Bool = false) -> Bool {
        let body = prefixed ? (value.hasPrefix("0x") ? value.dropFirst(2) : "") : Substring(value)
        return body.count == length && body.unicodeScalars.allSatisfy {
            ("0" ... "9").contains($0) || ("a" ... "f").contains($0) || ("A" ... "F").contains($0)
        }
    }
}

extension PerpsDepositQuoteReader {
    /// `Execute(bytes32 mode,Call[] calls,uint256 nonce,uint256 deadline)` and
    /// `Call(address target,uint256 value,bytes data)`: the types the delegate checks the
    /// signature against. Anything else would have the owner sign a different digest.
    private static let executeTypes: [String: [Components.Schemas.EIP712TypeField]] = [
        "Execute": [
            .init(name: "mode", _type: "bytes32"),
            .init(name: "calls", _type: "Call[]"),
            .init(name: "nonce", _type: "uint256"),
            .init(name: "deadline", _type: "uint256"),
        ],
        "Call": [
            .init(name: "target", _type: "address"),
            .init(name: "value", _type: "uint256"),
            .init(name: "data", _type: "bytes"),
        ],
    ]
    /// The domain's own type, when the document spells it rather than leaving it implied.
    private static let domainType: [Components.Schemas.EIP712TypeField] = [
        .init(name: "name", _type: "string"),
        .init(name: "version", _type: "string"),
        .init(name: "chainId", _type: "uint256"),
        .init(name: "verifyingContract", _type: "address"),
        .init(name: "salt", _type: "bytes32"),
    ]
    /// ERC-7821 single batch with `opData`: the mode in which HermesDelegateV1 runs calls signed
    /// by the account for someone else to submit.
    static let signedBatchMode = "0x0100000000007821000100000000000000000000000000000000000000000000"
    /// The delegate keeps a signature valid for at most a day.
    private static let longestExecuteDeadline: TimeInterval = 24 * 60 * 60

    /// Refuses a preview the wallet must not sign. The delegation outlives the deposit — the
    /// address runs the delegate's code until it authorizes another — and `Execute` lets anyone
    /// holding it run its calls as the account, so both are read down to the bytes signed: the
    /// one delegate this client was built for, and the one call that registers this key.
    static func readPreview(
        _ quote: Components.Schemas.DepositQuote,
        request: Components.Schemas.DepositQuoteRequest,
        registration: PerpsKeyRegistration,
        now: Date
    ) throws(PerpsDepositQuoteError) -> PerpsKeyRegistrationPreview {
        let checked = try terms(of: quote, request: request, now: now)
        guard quote.preview else {
            throw PerpsDepositQuoteError.unexpectedPreview(false)
        }
        // Paid from Ethereum, the payment would spend the nonce a delegation signed ahead is for,
        // so the payment delegates the address itself — the one it pays from and credits.
        // The direct route registers in its own batch.
        let ethereumSource = checked.sourceAsset.chain == .eth
        guard !ethereumSource || (
            checked.sourceAsset.raw.lowercased() != PerpsFundingAssetId.usdcEthereum
                && PerpsFundingAssetId.sameAddress(request.sender_address, request.destination_address)
        ) else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("preview for an Ethereum source")
        }
        let operation = try PerpsDepositOperation(quote.operation)
        let payloads = try operation.parsed().payloads
        let ethereum = MultichainChain.eth.asChainKitChain.caip2
        let authorizationPayload = payloads.first(where: { $0.type == .eip7702authorization })
        let authorization = authorizationPayload?.meta as? PayloadMetaEvmAuthorization
        guard payloads.count == (ethereumSource ? 1 : 2),
              payloads.allSatisfy({ $0.chain.caip2 == ethereum && $0.version == 1 }),
              (authorization == nil) == ethereumSource,
              let executePayload = payloads.first(where: { $0.type == .eip7821hermesdelegate }),
              let execute = executePayload.meta as? PayloadMetaEvmHermesDelegate
        else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("payloads")
        }
        if let authorization {
            guard authorization.chainId == 1,
                  authorization.address.display.lowercased() == PerpsDepositCalldata.hermesDelegate,
                  (Int64(authorization.nonce.description) ?? -1) >= 0
            else {
                throw PerpsDepositQuoteError.malformedKeyRegistration("authorization")
            }
        }
        try readExecute(execute.typedData, owner: request.destination_address, registration: registration, now: now)
        return PerpsKeyRegistrationPreview(
            quoteId: quote.quote_id,
            expiresAt: quote.expires_at,
            sourceAsset: checked.sourceAsset,
            sourceAmountUnits: checked.budget.description,
            sender: request.sender_address,
            beneficiary: request.destination_address,
            depositAmountUnits: checked.expected.description,
            registration: registration,
            operation: operation,
            delegationPayloadId: authorizationPayload?.id,
            executePayloadId: executePayload.id
        )
    }

    /// Reads the document exactly as ChainKit will sign it.
    private static func readExecute(
        _ typedData: String,
        owner: String,
        registration: PerpsKeyRegistration,
        now: Date
    ) throws(PerpsDepositQuoteError) {
        guard let document = try? JSONDecoder().decode(Components.Schemas.HermesExecuteTypedData.self, from: Data(typedData.utf8)) else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute document")
        }
        var types = document.types.additionalProperties
        if let declared = types.removeValue(forKey: "EIP712Domain"), declared != domainType {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute domain type")
        }
        guard document.primaryType == "Execute", types == executeTypes else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute types")
        }
        let domain = document.domain
        let salt = "0x" + String(repeating: "0", count: 24) + PerpsDepositCalldata.hermesDelegate.dropFirst(2)
        guard domain.name == "Hermes",
              domain.version == "v1.0.0",
              domain.chainId == 1,
              domain.verifyingContract.lowercased() == owner.lowercased(),
              domain.salt.lowercased() == salt
        else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute domain")
        }
        let message = document.message
        guard message.mode.lowercased() == signedBatchMode,
              message.calls.count == 1,
              let call = message.calls.first,
              call.target.lowercased() == PerpsDepositCalldata.gatewayAddress,
              call.value == "0",
              call.data.lowercased() == registration.calldata
        else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute call")
        }
        guard (Int64(message.nonce) ?? -1) >= 0,
              let deadline = Int64(message.deadline),
              TimeInterval(deadline) > now.timeIntervalSince1970,
              TimeInterval(deadline) <= now.timeIntervalSince1970 + longestExecuteDeadline
        else {
            throw PerpsDepositQuoteError.malformedKeyRegistration("execute nonce or deadline")
        }
    }
}
