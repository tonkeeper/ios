import BigInt
import ChainKit
import Foundation
import PerpsModels
import TKLogging
import TKPerpsAPI
import TonSwift
import TronSwift

/// A funding asset as the backend spells it: `<chain>/mainnet/coin` for a chain's own
/// coin, `<chain>/mainnet/erc20/<address>` for a token — `bep20` on bsc, `trc20/<base58>` on tron.
struct PerpsFundingAssetId: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case coin
        case token(address: String)
    }

    let raw: String
    let chain: MultichainChain
    let kind: Kind

    /// `<chain>/<network>`, the form a payload names the chain to broadcast on.
    var chainId: String {
        chain.fundingChainId
    }

    /// The coin the network fee is paid in, as it is spelled for display.
    var nativeSymbol: String {
        switch chain {
        case .ton: TonInfo.symbol
        case .bsc: "BNB"
        case .tron: "TRX"
        case .btc: "BTC"
        case .polygon: "POL"
        case .avax: "AVAX"
        case .sol: "SOL"
        case .eth, .base, .arb, .robinhood: "ETH"
        }
    }

    var nativeDecimals: Int {
        switch chain {
        case .ton, .sol: 9
        case .tron: 6
        case .btc: 8
        case .eth, .base, .arb, .bsc, .polygon, .avax, .robinhood: 18
        }
    }

    /// Where a deposit always lands: Lighter's gateway credits USDC on Ethereum, so a
    /// quote naming anything else as its output is not a deposit this client can record.
    static let usdcEthereum = "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

    static func parse(_ raw: String) -> PerpsFundingAssetId? {
        let spelled = raw.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let parts = spelled.map { $0.lowercased() }
        guard parts.count >= 3,
              let chain = MultichainChain(fundingChainId: "\(parts[0])/\(parts[1])")
        else { return nil }
        switch (parts[2], parts.count) {
        case ("coin", 3):
            return Self(raw: raw, chain: chain, kind: .coin)
        case ("erc20", 4) where chain.isEVM && isEthereumAddress(parts[3]):
            return Self(raw: raw, chain: chain, kind: .token(address: parts[3]))
        case ("bep20", 4) where chain == .bsc && isEthereumAddress(parts[3]):
            return Self(raw: raw, chain: chain, kind: .token(address: parts[3]))
        // Base58 is case-sensitive, so a Tron token keeps the spelling it came with.
        case ("trc20", 4) where chain == .tron && isTronAddress(spelled[3]):
            return Self(raw: raw, chain: chain, kind: .token(address: spelled[3]))
        case ("jetton", 4) where chain == .ton && (try? TonSwift.Address.parse(spelled[3])) != nil:
            return Self(raw: raw, chain: chain, kind: .token(address: spelled[3]))
        default:
            return nil
        }
    }

    static func isEthereumAddress(_ value: String) -> Bool {
        value.count == 42
            && value.hasPrefix("0x")
            && value.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    static func isTronAddress(_ value: String) -> Bool {
        (try? TronSwift.Address(address: value)) != nil
    }

    static func bitcoinAddress(_ value: String) -> String? {
        if let first = value.first, first == "1" || first == "3", (26 ... 35).contains(value.count),
           value.allSatisfy({ base58Alphabet.contains($0) })
        {
            return value
        }
        let bech32 = value.lowercased()
        guard value == bech32 || value == value.uppercased(),
              bech32.hasPrefix("bc1"), (11 ... 90).contains(bech32.count),
              bech32.dropFirst(3).allSatisfy({ bech32Alphabet.contains($0) })
        else { return nil }
        return bech32
    }

    private static let base58Alphabet = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let bech32Alphabet = Set("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    /// Ethereum spells one address in several cases and TON in several encodings — raw,
    /// bounceable, non-bounceable — so those are compared by what they name. Tron and
    /// Bitcoin addresses are compared as written.
    static func sameAddress(_ lhs: String, _ rhs: String) -> Bool {
        if isEthereumAddress(lhs.lowercased()), isEthereumAddress(rhs.lowercased()) {
            return lhs.lowercased() == rhs.lowercased()
        }
        if let lhs = try? TonSwift.Address.parse(lhs), let rhs = try? TonSwift.Address.parse(rhs) {
            return lhs == rhs
        }
        return lhs == rhs
    }
}

extension MultichainChain {
    /// A funding payload names its chain `<chain>/mainnet`, spelled as the asset id spells it.
    init?(fundingChainId: String) {
        let parts = fundingChainId.lowercased().split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1] == "mainnet" else { return nil }
        self.init(rawValue: String(parts[0]))
    }

    var fundingChainId: String {
        "\(rawValue)/mainnet"
    }
}

enum PerpsDepositProvider: String, Sendable, Equatable {
    case direct
    case relay
    case funxyz
    case omniston

    static let relayName = "Relay"
    static let bridgeSources: Set<String> = [
        PerpsFundingAssetId.usdcEthereum,
        "arb/mainnet/erc20/0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "base/mainnet/erc20/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
        "polygon/mainnet/erc20/0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
    ]
}

enum PerpsDepositQuoteError: Error, Equatable {
    case expired(Date)
    case echoMismatch(field: String)
    case beneficiaryMismatch(expected: String, quoted: String)
    case unexpectedTargetAsset(String)
    case malformedAmount(field: String)
    /// The deposit is exact, so `min_amount` and `expected_amount` disagreeing means the
    /// quote is not the one this contract describes.
    case inexactDeposit(expected: String, minimum: String)
    case belowGatewayMinimum(String)
    case unsupportedSourceAsset(String)
    case missingTracking
    /// ChainKit could not read the operation, so there is nothing this client could sign.
    case malformedOperation(String)
    case approvalWithoutMain
    /// A deposit is one payment, behind at most one approval: any other sequence holds a
    /// step the term checks do not read.
    case unexpectedPayloads([String])
    case payloadChainMismatch(payloadId: String, expected: String, quoted: String)
    case malformedPayload(payloadId: String)
    /// A TON send mode asking for more than the payload's own `value`.
    case unboundedSendMode(payloadId: String, mode: Int)
    case overspend(spent: String, budget: String)
    /// A quote to send is not a preview; a preview is a key registration's, signatures only.
    case unexpectedPreview(Bool)
    case malformedKeyRegistration(String)
    case unexpectedTonPayment(String)
    case unexpectedProvider(String)
    case unexpectedChainPayment(String)
    case unexpectedBitcoinPayment(String)
}

/// The EIP-7702 authorization a folded deposit carries: from this transaction on, the sender's
/// address runs `address`'s code, and it keeps it after the deposit.
struct PerpsDepositDelegation: Sendable, Equatable {
    let chainId: Int64
    let address: String
    /// The sender's nonce after the transaction's own, which the chain checks it against.
    let nonce: Int64
}

/// A payload as ChainKit read it, in the terms this client checks before anything is signed.
struct PerpsDepositQuotePayload: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case approval
        case main
        /// An ERC-7821 `execute` the sender sends to itself, running the approval and the
        /// payment as one all-or-nothing transaction.
        case batch
        /// A transaction the backend built whole, signed as it stands: on Bitcoin a PSBT.
        case prebuilt
    }

    let payloadId: String
    let kind: Kind
    let chainId: String
    /// Empty on a prebuilt transaction.
    let to: String
    /// Smallest units, as digits: what the chain's own transaction will carry.
    let valueUnits: String
    /// EVM and Tron calldata as `0x` hex, a TON body as a base64 BOC, a PSBT as base64.
    let data: String?
    let mode: Int?
    let gasLimitUnits: String?
    let delegation: PerpsDepositDelegation?
}

/// The operation exactly as the backend sent it. What is signed is parsed from these bytes
/// again, so it is the same operation the quote was checked against.
struct PerpsDepositOperation: Sendable, Equatable, Codable {
    let id: String
    /// The payload array, as JSON.
    let payloads: String

    init(_ operation: Components.Schemas.DepositOperation) throws(PerpsDepositQuoteError) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        guard let data = try? encoder.encode(operation.payloads), let payloads = String(data: data, encoding: .utf8) else {
            throw PerpsDepositQuoteError.malformedOperation(operation.id)
        }
        id = operation.id
        self.payloads = payloads
    }

    private init(id: String, payloads: String) {
        self.id = id
        self.payloads = payloads
    }

    func parsed() throws(PerpsDepositQuoteError) -> ChainKit.Operation {
        do {
            return try ChainKitOperationSender.parse(id: id, payloads: payloads)
        } catch {
            Log.perps.w("Deposit operation unreadable id=\(id)", error: error)
            throw PerpsDepositQuoteError.malformedOperation(id)
        }
    }

    /// `nil` once any payload is unpriced: a partial sum would understate the fee.
    func quotedNetworkFeeUnits(on chain: MultichainChain) -> BigUInt? {
        guard let total = try? parsed().quotedFeeAmount(asset: chain.asChainKitChain.toAsset()) else { return nil }
        return BigUInt(total.description)
    }

    func quotedFeeUnits(on chain: MultichainChain) throws(PerpsDepositQuoteError) -> [(payloadId: String, units: BigUInt)] {
        let coinId = chain.asChainKitChain.toAsset().id
        return try parsed().payloads.compactMap { payload in
            guard let fee = payload.fee as? FeeValue, fee.asset.id == coinId, let units = BigUInt(fee.amount.description) else {
                return nil
            }
            return (payload.id, units)
        }
    }

    func charging(_ fees: [String: BigUInt]) throws(PerpsDepositQuoteError) -> PerpsDepositOperation {
        guard !fees.isEmpty else { return self }
        guard var payloads = try? JSONSerialization.jsonObject(with: Data(payloads.utf8)) as? [[String: Any]] else {
            throw PerpsDepositQuoteError.malformedOperation(id)
        }
        for index in payloads.indices {
            guard let payloadId = payloads[index]["id"] as? String, let units = fees[payloadId] else { continue }
            guard var fee = payloads[index]["fee"] as? [String: Any], fee["type"] as? String == "value",
                  var data = fee["data"] as? [String: Any]
            else {
                throw PerpsDepositQuoteError.malformedPayload(payloadId: payloadId)
            }
            data["amount"] = units.description
            fee["data"] = data
            payloads[index]["fee"] = fee
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payloads, options: [.withoutEscapingSlashes]),
              let charged = String(data: data, encoding: .utf8)
        else {
            throw PerpsDepositQuoteError.malformedOperation(id)
        }
        return PerpsDepositOperation(id: id, payloads: charged)
    }
}

/// A quote envelope the client has checked against its own request. Building
/// one is the only way funding reads `POST /funding/quote`: the backend states what will
/// be credited, but the wallet signs the payloads, so it verifies the terms first.
struct PerpsDepositQuote: Sendable, Equatable {
    let quoteId: String
    let route: PerpsDepositRoute
    let provider: PerpsDepositProvider
    let expiresAt: Date
    let sourceAsset: PerpsFundingAssetId
    let sourceAmountUnits: String
    /// The address the payloads were built for, as this client asked.
    let sender: String
    /// The wallet's own Ethereum address, as this client asked to have credited.
    let beneficiary: String
    let targetAssetId: String
    let depositAmountUnits: String
    var operation: PerpsDepositOperation
    let payloads: [PerpsDepositQuotePayload]
    let executionId: String?
    /// The requested key; on the direct route, present only when the batch registers it.
    var registration: PerpsKeyRegistration?
    /// Whether Lighter knows no account for the beneficiary yet; `nil` when it did not answer in time.
    var accountUninitialized: Bool?
    var estimatedDurationSeconds: Int? = nil
    var providerFees: PerpsDepositProviderFees? = nil
    var relayPaymentUnits: BigUInt? = nil
    var bitcoinPayment: PerpsBitcoinDeposit? = nil
}

extension Components.Schemas.DepositQuote {
    /// Zero when the provider states none; `nil` once one is unreadable, as a partial sum would
    /// understate them.
    var providerFees: PerpsDepositProviderFees? {
        var destinationGas: Foundation.Decimal = 0
        var provider: Foundation.Decimal = 0
        for fee in fees ?? [] {
            guard let amount = Foundation.Decimal(string: fee.amount_usd, locale: Locale(identifier: "en_US_POSIX")),
                  !amount.isNaN, amount >= 0
            else { return nil }
            if fee._type == "destination_gas" {
                destinationGas += amount
            } else {
                provider += amount
            }
        }
        return PerpsDepositProviderFees(destinationGasUsd: destinationGas, providerUsd: provider)
    }
}

enum PerpsDepositQuoteReader {
    /// Refuses a quote the wallet must not sign. Payload calldata itself stays opaque
    /// here — `PerpsDepositService` checks the calls against these terms and the
    /// environment's contract addresses.
    static func read(
        _ quote: Components.Schemas.DepositQuote,
        request: Components.Schemas.DepositQuoteRequest,
        registration: PerpsKeyRegistration? = nil,
        security: PerpsSecurityConfig?,
        now: Date
    ) throws(PerpsDepositQuoteError) -> PerpsDepositQuote {
        let (sourceAsset, budget, expected) = try terms(of: quote, request: request, now: now)
        guard !quote.preview else {
            throw PerpsDepositQuoteError.unexpectedPreview(true)
        }

        guard let provider = PerpsDepositProvider(rawValue: quote.provider) else {
            throw PerpsDepositQuoteError.unexpectedProvider(quote.provider)
        }
        let route: PerpsDepositRoute
        let executionId: String?
        // `tracking` is absent exactly when USDC on Ethereum goes straight to the gateway. Anything
        // tracked is a fill to follow, USDC on Ethereum included: Lighter's bridge takes a top-up of an
        // existing account from there too.
        if let tracking = quote.tracking {
            guard !tracking.execution_id.isEmpty else {
                throw PerpsDepositQuoteError.missingTracking
            }
            guard provider != .direct else {
                throw PerpsDepositQuoteError.unexpectedProvider(quote.provider)
            }
            route = .crosschainSwap
            executionId = tracking.execution_id
        } else {
            guard sourceAsset.raw.lowercased() == PerpsFundingAssetId.usdcEthereum, provider == .direct else {
                throw PerpsDepositQuoteError.missingTracking
            }
            route = .directGateway
            executionId = nil
        }

        let operation = try PerpsDepositOperation(quote.operation)
        // From Ethereum the payment itself delegates the address the key's `Execute` runs on (`readPreview`).
        let delegatedPayment = registration != nil && route == .crosschainSwap && sourceAsset.chain == .eth
            && PerpsFundingAssetId.sameAddress(request.sender_address, request.destination_address)
        let read = try payloads(
            of: operation,
            sourceAsset: sourceAsset,
            sender: request.sender_address,
            delegatedPayment: delegatedPayment,
            security: security
        )
        // A coin payment spends the budget through `value`, or through the outputs of a
        // prebuilt transaction. A token's budget travels in the calldata. On EVM and Tron a
        // transaction pays its fee outside `value`, so native value beside a token is a transfer
        // this quote never asked for. A jetton transfer is a message to the wallet's jetton
        // wallet, and the coin it carries pays that contract's gas, so no budget bounds it.
        let nativeBudget: BigUInt? = switch sourceAsset.kind {
        case .coin: budget
        case .token: sourceAsset.chain == .ton ? nil : 0
        }
        if let nativeBudget, read.totalValue > nativeBudget {
            throw PerpsDepositQuoteError.overspend(
                spent: read.totalValue.description,
                budget: nativeBudget.description
            )
        }

        return PerpsDepositQuote(
            quoteId: quote.quote_id,
            route: route,
            provider: provider,
            expiresAt: quote.expires_at,
            sourceAsset: sourceAsset,
            sourceAmountUnits: budget.description,
            sender: request.sender_address,
            beneficiary: request.destination_address,
            targetAssetId: quote.output.asset_id,
            depositAmountUnits: expected.description,
            operation: operation,
            payloads: read.payloads,
            executionId: executionId,
            registration: registration,
            accountUninitialized: quote.account_uninitialized,
            estimatedDurationSeconds: quote.estimated_duration_seconds.map(Int.init),
            providerFees: quote.providerFees
        )
    }

    /// The envelope checks every quote answers to, a deposit or a key-registration preview:
    /// it echoes the request, credits this wallet in USDC on Ethereum, and exactly.
    static func terms(
        of quote: Components.Schemas.DepositQuote,
        request: Components.Schemas.DepositQuoteRequest,
        now: Date
    ) throws(PerpsDepositQuoteError) -> (sourceAsset: PerpsFundingAssetId, budget: BigUInt, expected: BigUInt) {
        guard quote.expires_at > now else {
            throw PerpsDepositQuoteError.expired(quote.expires_at)
        }
        guard let sourceAsset = PerpsFundingAssetId.parse(request.source_asset) else {
            throw PerpsDepositQuoteError.unsupportedSourceAsset(request.source_asset)
        }
        guard quote.input.asset_id.lowercased() == sourceAsset.raw.lowercased() else {
            throw PerpsDepositQuoteError.echoMismatch(field: "source_asset")
        }
        guard quote.input.amount == request.source_amount else {
            throw PerpsDepositQuoteError.echoMismatch(field: "source_amount")
        }
        guard PerpsFundingAssetId.sameAddress(quote.input.address, request.sender_address) else {
            throw PerpsDepositQuoteError.echoMismatch(field: "sender_address")
        }
        guard PerpsFundingAssetId.sameAddress(quote.output.address, request.destination_address) else {
            throw PerpsDepositQuoteError.beneficiaryMismatch(
                expected: request.destination_address,
                quoted: quote.output.address
            )
        }
        guard quote.output.asset_id.lowercased() == PerpsFundingAssetId.usdcEthereum else {
            throw PerpsDepositQuoteError.unexpectedTargetAsset(quote.output.asset_id)
        }

        let budget = try units(request.source_amount, field: "source_amount")
        let expected = try units(quote.output.amount, field: "expected_amount")
        let minimum = try units(quote.output.min_amount, field: "min_amount")
        guard expected == minimum else {
            throw PerpsDepositQuoteError.inexactDeposit(
                expected: quote.output.amount,
                minimum: quote.output.min_amount
            )
        }
        guard expected >= PerpsFundingAmount.gatewayMinimumUsdcUnits else {
            throw PerpsDepositQuoteError.belowGatewayMinimum(quote.output.amount)
        }
        return (sourceAsset, budget, expected)
    }

    /// On TON the send mode is spending authority of its own, so `value` alone does not
    /// say what a message costs: `+128` hands over the whole wallet balance and `+64` the
    /// whole inbound value, neither of which the budget bounds, and `+32` deletes the
    /// wallet once it is empty. What is left — pay the fee separately, ignore action
    /// errors — spends exactly the payload's own `value`, so a quote
    /// may ask for those and nothing else.
    private static let allowedSendModeFlags = 1 | 2

    static func payloads(
        of operation: PerpsDepositOperation,
        sourceAsset: PerpsFundingAssetId,
        sender: String,
        delegatedPayment: Bool = false,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> (payloads: [PerpsDepositQuotePayload], totalValue: BigUInt) {
        let sourceChainId = sourceAsset.chainId
        let chain = sourceAsset.chain
        var read = [PerpsDepositQuotePayload]()
        var totalValue = BigUInt(0)
        for payload in try operation.parsed().payloads {
            guard payload.chain.caip2 == chain.asChainKitChain.caip2 else {
                throw PerpsDepositQuoteError.payloadChainMismatch(
                    payloadId: payload.id,
                    expected: sourceChainId,
                    quoted: payload.chain.caip2
                )
            }
            // A shape this client was not built for is refused, never guessed at.
            guard let meta = Meta(payload, chain: chain) else { throw malformed(payload, reason: "meta") }
            if case let .prebuilt(prebuild) = meta {
                let spent = try Self.spent(by: prebuild, of: payload, sender: sender)
                totalValue += spent
                read.append(PerpsDepositQuotePayload(
                    payloadId: payload.id,
                    kind: .prebuilt,
                    chainId: sourceChainId,
                    to: "",
                    valueUnits: spent.description,
                    data: prebuild.data,
                    mode: nil,
                    gasLimitUnits: nil,
                    delegation: nil
                ))
                continue
            }
            guard case let .main(to, valueUnits, data, mode, gasLimitUnits, authorization) = meta,
                  let value = try? PerpsFundingAmount.integerUnits(valueUnits)
            else { throw malformed(payload, reason: "value") }
            if let mode, mode & ~allowedSendModeFlags != 0 {
                throw PerpsDepositQuoteError.unboundedSendMode(payloadId: payload.id, mode: mode)
            }
            // A call into the sender's own address runs whatever code it has as the account, so it
            // is signed only as the batch the contract folds a token deposit into where Hermes runs.
            // A delegation rides on that batch, or on a payment that registers the key from Ethereum.
            let isSelfCall = chain != .ton && PerpsFundingAssetId.sameAddress(to, sender)
            if isSelfCall {
                // Signing no delegation, the batch needs no signed block: without one, the built-in chains stand.
                let hermesRuns = security.map { $0.delegates(on: chain) } ?? PerpsDepositCalldata.hermesChains.contains(chain)
                guard hermesRuns, case .token = sourceAsset.kind else {
                    throw malformed(payload, reason: "self-call")
                }
            } else if authorization != nil, !delegatedPayment {
                throw malformed(payload, reason: "delegation")
            }
            var delegation: PerpsDepositDelegation?
            if let authorization {
                delegation = try Self.delegation(authorization, of: payload, chain: chain, security: security)
            }
            totalValue += value
            read.append(PerpsDepositQuotePayload(
                payloadId: payload.id,
                kind: isSelfCall ? .batch : isApproval(to: to, data: data, sourceAsset: sourceAsset) ? .approval : .main,
                chainId: sourceChainId,
                to: to,
                valueUnits: valueUnits,
                data: data,
                mode: mode,
                gasLimitUnits: gasLimitUnits,
                delegation: delegation
            ))
        }
        // The client signs only on the source chain, and an approval is worth signing
        // only for a main that follows it.
        guard read.last?.kind != .approval else {
            throw PerpsDepositQuoteError.approvalWithoutMain
        }
        return (read, totalValue)
    }

    /// The delegate's code runs as the account from then on, so the one contract the backend
    /// signed in `security`, on a chain it names, is the whole of what it signs an authorization for.
    private static func delegation(
        _ authorization: PayloadMetaEvmAuthorization,
        of payload: Payload,
        chain: MultichainChain,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> PerpsDepositDelegation {
        guard let security,
              security.delegates(on: chain),
              authorization.address.display.lowercased() == security.hermesDelegate
        else {
            throw malformed(payload, reason: "delegate")
        }
        // Whether it is the sender's next nonce only the live account says, so the send checks that.
        guard authorization.chainId == chain.eip155ChainId.map(Int64.init),
              let nonce = Int64(authorization.nonce.description), nonce >= 1
        else {
            throw malformed(payload, reason: "authorization")
        }
        return PerpsDepositDelegation(
            chainId: authorization.chainId,
            address: security.hermesDelegate,
            nonce: nonce
        )
    }

    /// What a prebuilt transaction pays away: every output but the change back to `sender` and a
    /// valueless OP_RETURN. A script ChainKit cannot name could pay anyone, so one carrying value
    /// is refused rather than counted.
    private static func spent(
        by prebuild: PayloadMetaBitcoinPrebuild,
        of payload: Payload,
        sender: String
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let outputs = prebuild.outputs(chain: payload.chain).getOrNull() as? [PsbtOutput] else {
            throw malformed(payload, reason: "psbt")
        }
        var spent = BigUInt(0)
        for output in outputs {
            guard let value = BigUInt(output.value.description) else { throw malformed(payload, reason: "psbt value") }
            guard let address = output.address else {
                guard value == 0 else { throw malformed(payload, reason: "psbt script") }
                continue
            }
            if !PerpsFundingAssetId.sameAddress(address.display, sender) {
                spent += value
            }
        }
        return spent
    }

    private static func malformed(_ payload: Payload, reason: String) -> PerpsDepositQuoteError {
        Log.perps.w("Deposit quote payload malformed id=\(payload.id) type=\(payload.type.id) version=\(payload.version) reason=\(reason)")
        return .malformedPayload(payloadId: payload.id)
    }

    /// The contract names no approval role: every payload is `main`, and an approval is an
    /// ERC-20 `approve` sent to the source token itself. Its spender and amount are checked
    /// by `PerpsDepositCalldata.readApproval` before anything is signed.
    private static func isApproval(to: String, data: String?, sourceAsset: PerpsFundingAssetId) -> Bool {
        guard case let .token(address) = sourceAsset.kind,
              PerpsFundingAssetId.sameAddress(to, address),
              let data = data?.lowercased()
        else { return false }
        return data.hasPrefix("0x" + PerpsDepositCalldata.approveSelector)
    }

    private static func units(_ value: String, field: String) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let units = try? PerpsFundingAmount.integerUnits(value) else {
            throw PerpsDepositQuoteError.malformedAmount(field: field)
        }
        return units
    }
}

private enum Meta {
    case main(
        to: String,
        valueUnits: String,
        data: String?,
        mode: Int?,
        gasLimitUnits: String?,
        authorization: PayloadMetaEvmAuthorization?
    )
    case prebuilt(PayloadMetaBitcoinPrebuild)

    /// The shapes a deposit is paid with: a TonConnect message, an EVM or Tron transaction,
    /// and a Bitcoin PSBT the backend built whole.
    init?(_ payload: Payload, chain: MultichainChain) {
        guard payload.version == 1 else { return nil }
        switch (payload.type, payload.meta) {
        case let (.main, meta as PayloadMetaTonMain) where chain == .ton && meta.stateInit == nil && meta.token == nil
            && (meta.comment ?? "").isEmpty:
            self = .main(
                to: meta.to.display,
                valueUnits: meta.value.description,
                data: meta.body,
                mode: meta.mode.map { Int(truncating: $0) },
                gasLimitUnits: nil,
                authorization: nil
            )
        case let (.main, meta as PayloadMetaEvmMain) where chain.isEVM:
            self = .main(
                to: meta.to.display,
                valueUnits: meta.value.description,
                data: meta.data,
                mode: nil,
                gasLimitUnits: meta.gas?.description,
                authorization: meta.authorization
            )
        case let (.main, meta as PayloadMetaTronMain) where chain == .tron && (meta.memo ?? "").isEmpty:
            self = .main(
                to: meta.to.display,
                valueUnits: meta.value.description,
                data: meta.data.map { $0.lowercased().hasPrefix("0x") ? $0 : "0x" + $0 },
                mode: nil,
                gasLimitUnits: nil,
                authorization: nil
            )
        case let (.prebuild, meta as PayloadMetaBitcoinPrebuild) where chain == .btc && !meta.data.isEmpty:
            self = .prebuilt(meta)
        default:
            return nil
        }
    }
}
