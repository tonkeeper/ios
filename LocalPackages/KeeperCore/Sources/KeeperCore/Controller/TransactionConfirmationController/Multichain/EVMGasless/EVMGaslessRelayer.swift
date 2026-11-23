import BigInt
import ChainKit
import Foundation
import TKBatteryAPI
import TKLogging

/// One asset the relayer can take its fee in, at the price its estimate named.
struct EVMGaslessEstimation: Equatable {
    let asset: Components.Schemas.GaslessV2Asset
    let fee: BigUInt
    /// False when the sender cannot afford the fee in this asset, as the relayer sees it.
    let isAvailable: Bool

    var isBattery: Bool {
        asset.id == AssetBattery.Companion.shared.ID
    }
}

/// A relayed send prepared by the relayer's emulation: the price it holds the sender to, and the
/// documents to sign, kept by the relayer until `expiresAt`.
struct EVMGaslessEmulation {
    let assetId: String
    let fee: BigUInt
    let operation: MultichainRelayedOperation
    let expiresAt: Date

    /// Signing takes a moment and the relayer checks the deadline when the signatures arrive.
    static let expiryLead: TimeInterval = 5

    func isExpired(at now: Date = Date()) -> Bool {
        expiresAt.addingTimeInterval(-Self.expiryLead) <= now
    }

    func deadlineReference(at now: Date = Date()) -> Date {
        min(now, expiresAt.addingTimeInterval(-1))
    }
}

enum EVMGaslessRelayerError: Error, Equatable {
    /// The emulated operation is gone: quote it again before sending.
    case quoteExpired
    /// The relayer answered something other than what it was asked for, or refused the operation.
    case rejected(reason: String, mayHaveBroadcast: Bool = false)
    /// The signed operation is not the envelope `/gasless/send` takes.
    case malformedEnvelope(reason: String)
}

extension EVMGaslessRelayerError: LoggableError {
    var logDescription: String {
        switch self {
        case .quoteExpired:
            return "type=EVMGaslessRelayerError, case=quoteExpired"
        case let .rejected(reason, _):
            return "type=EVMGaslessRelayerError, case=rejected, reason=\(reason)"
        case let .malformedEnvelope(reason):
            return "type=EVMGaslessRelayerError, case=malformedEnvelope, reason=\(reason)"
        }
    }
}

/// `/gasless/send` answers 200 for an operation the relayer has taken. A status this client does not
/// know leaves the operation possibly broadcast, so it is not a refusal.
struct EVMGaslessUnknownSendStatus: LoggableError {
    let operationId: String

    var logDescription: String {
        "type=EVMGaslessUnknownSendStatus, operationId=\(operationId)"
    }
}

protocol EVMGaslessRelaying {
    /// Prices `call` in every asset that can pay the relayer on its chain.
    func estimate(wallet: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation]
    /// Builds the operation to sign with the fee taken in `assetId`: one for all of `calls`, which
    /// run in order as one batch of the same sender's on the same chain.
    func emulate(wallet: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation
    /// Builds the operation to sign for `batch`'s payload as it stands, with the fee in battery charges.
    func emulate(wallet: Wallet, batch: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation
    /// Hands the signed operation envelope, `{"operation": …}` as ChainKit writes it, to the relayer.
    /// An error other than an `EVMGaslessRelayerError` leaves the operation possibly broadcast.
    /// Returns the hash of the transaction the relayer broadcast, when it names one.
    func send(wallet: Wallet, signedOperation: Data) async throws -> String?
}

extension EVMGaslessRelaying {
    func emulate(wallet: Wallet, call: EVMGaslessCall, assetId: String) async throws -> EVMGaslessEmulation {
        try await emulate(wallet: wallet, calls: [call], assetId: assetId)
    }
}

/// The battery's gasless 2.0 relayer.
struct BatteryEVMGaslessRelayer: EVMGaslessRelaying {
    let service: BatteryGaslessService

    static let expiredErrorCodes: Set<String> = ["emulation_expired", "operation_not_found"]
    /// The answer to an operation sent before, whose first send may have landed.
    static let alreadySentErrorCode = "already_sent"
    /// Refusals the relayer gives before it broadcasts; after any other the transaction may be on chain.
    private static let preBroadcastErrorCodes: Set<String> = [
        "invalid_signature", "payload_mismatch", "unsupported_chain", "unsupported_asset", "unsupported_payload",
        "emulation_failed", "route_not_sponsorable", "bad_request", "unauthorized", "insufficient_funds", "not_implemented",
    ]

    func estimate(wallet: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        let payload = try call.payload()
        let response = try await service.estimateGasless(
            wallet: wallet,
            request: Components.Schemas.GaslessV2EstimateRequest(
                chain_id: call.chainId,
                sender_address: call.sender,
                payload: payload
            )
        )
        return response.estimations.compactMap { estimation in
            guard let fee = estimation.fee, fee._type == .value else {
                return nil
            }
            guard let amount = fee.data.amount.flatMap({ BigUInt($0) }) else {
                Log.multichain.w("gasless estimation: a value fee amount is not a number: \(fee.data.amount ?? "none")")
                return nil
            }
            return EVMGaslessEstimation(asset: estimation.asset, fee: amount, isAvailable: estimation.available)
        }
    }

    func emulate(wallet: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        guard let call = calls.first,
              calls.allSatisfy({ $0.chainId == call.chainId && $0.sender == call.sender && $0.kind == call.kind })
        else {
            throw EVMGaslessRelayerError.rejected(reason: "\(calls.count) calls are not one sender's batch")
        }
        let payloads = try calls.enumerated().map { index, call in
            try call.payload(id: String(format: "p_%02d", index + 1))
        }
        return try await emulate(
            wallet: wallet,
            request: Components.Schemas.GaslessV2EmulateRequest(
                chain_id: call.chainId,
                sender_address: call.sender,
                _type: call.kind.rawValue,
                gasless_asset: assetId,
                payloads: payloads
            ),
            sent: ["calls": calls.map { "\($0.to):\($0.data.prefix(10)):\($0.value)" }.joined(separator: ",")]
        )
    }

    func emulate(wallet: Wallet, batch: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        try await emulate(
            wallet: wallet,
            request: Components.Schemas.GaslessV2EmulateRequest(
                chain_id: batch.chain.relayerChainId,
                sender_address: batch.sender,
                _type: EVMGaslessCall.Kind.swap.rawValue,
                gasless_asset: assetId,
                payloads: [batch.payload]
            ),
            sent: ["payload": "\(batch.payload.id):\(batch.payload._type)"]
        )
    }

    private func emulate(
        wallet: Wallet,
        request: Components.Schemas.GaslessV2EmulateRequest,
        sent: [String: String]
    ) async throws -> EVMGaslessEmulation {
        let assetId = request.gasless_asset
        let response = try await service.emulateGasless(wallet: wallet, request: request)
        Log.multichain.i(
            "gasless emulated",
            extraInfo: sent.merging([
                "chain": request.chain_id,
                "asset": response.asset_id,
                "fee": response.fee.data.amount ?? "none",
                "delegated": response.account.map { "\($0.delegated) to \($0.delegated_to ?? "none")" } ?? "unknown",
                "requiresAuthorization": response.account.map { "\($0.requires_authorization)" } ?? "unknown",
                "gas": response.gas.map { "estimated \($0.estimated), charged \($0.charged), authorization \($0.authorization_gas ?? "0")" } ?? "unknown",
                "operationId": response.operation.id,
                "operationPayloads": response.operation.payloads.map { "\($0.id):\($0._type)" }.joined(separator: ","),
                "expiresAt": "\(response.expires_at)",
            ]) { $1 }
        )
        guard response.asset_id == assetId else {
            throw EVMGaslessRelayerError.rejected(reason: "emulated in \(response.asset_id), asked for \(assetId)")
        }
        guard response.fee._type == .value else {
            throw EVMGaslessRelayerError.rejected(reason: "unsupported emulation fee type: \(response.fee._type.rawValue)")
        }
        guard let fee = response.fee.data.amount.flatMap({ BigUInt($0) }) else {
            throw EVMGaslessRelayerError.rejected(reason: "emulation fee is not a number: \(response.fee.data.amount ?? "none")")
        }
        let operationJSON: Data
        do {
            operationJSON = try JSONEncoder().encode(response.operation)
        } catch {
            throw EVMGaslessRelayerError.rejected(reason: "emulated operation cannot be written back: \(error.logDescription)")
        }
        let operation = try MultichainRelayedOperation(
            id: response.operation.id,
            json: String(decoding: operationJSON, as: UTF8.self),
            allowedTypes: Self.relayedTypes(on: request.chain_id)
        )
        if request.chain_id == MultichainChain.sol.relayerChainId {
            try Self.requireRelayerPaysFee(of: operation, sender: request.sender_address)
        }
        return EVMGaslessEmulation(
            assetId: assetId,
            fee: fee,
            operation: operation,
            expiresAt: response.expires_at
        )
    }

    /// What the relayer hands back to sign: the EVM delegation documents, or on Solana the transaction
    /// it pays for, built in full.
    static func relayedTypes(on chainId: String) -> [ChainKit.Payload.Type_] {
        chainId == MultichainChain.sol.relayerChainId ? [.prebuild] : MultichainRelayedOperation.relayedTypes
    }

    /// A Solana transaction the sender pays the fee of is not relayed at all, whoever built it.
    private static func requireRelayerPaysFee(of operation: MultichainRelayedOperation, sender: String) throws(EVMGaslessRelayerError) {
        for payload in operation.operation.payloads {
            guard let transaction = (payload.meta as? PayloadMetaSolanaPrebuild)?.data,
                  let payer = BatteryPurchaseOperationGuard.solanaFeePayer(transaction),
                  payer != sender
            else {
                throw .rejected(reason: "payload \(payload.id) is not a transaction the relayer pays the fee of")
            }
        }
    }

    func send(wallet: Wallet, signedOperation: Data) async throws -> String? {
        let request: Components.Schemas.GaslessV2SendRequest
        do {
            request = try JSONDecoder().decode(Components.Schemas.GaslessV2SendRequest.self, from: signedOperation)
        } catch {
            throw EVMGaslessRelayerError.malformedEnvelope(reason: error.logDescription)
        }
        let response: Components.Schemas.GaslessV2SendResponse
        do {
            response = try await service.sendGasless(wallet: wallet, request: request)
        } catch let error as BatteryAPI.ApiError {
            if case let .rejected(_, code, message) = error, code != Self.alreadySentErrorCode {
                if Self.expiredErrorCodes.contains(code) {
                    throw EVMGaslessRelayerError.quoteExpired
                }
                throw EVMGaslessRelayerError.rejected(
                    reason: "\(code): \(message)",
                    mayHaveBroadcast: !Self.preBroadcastErrorCodes.contains(code)
                )
            }
            throw error
        }
        switch response.status {
        case .ok:
            return response.tx_hash?.isEmpty == false ? response.tx_hash : nil
        case .failed:
            throw EVMGaslessRelayerError.rejected(
                reason: "relayer answered `failed` to \(response.operation_id)",
                mayHaveBroadcast: true
            )
        case .unknown:
            throw EVMGaslessUnknownSendStatus(operationId: response.operation_id)
        }
    }
}
