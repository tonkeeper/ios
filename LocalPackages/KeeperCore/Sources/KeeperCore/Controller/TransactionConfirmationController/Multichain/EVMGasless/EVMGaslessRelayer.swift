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

    /// Battery is the one asset that is not chain-scoped.
    var isBattery: Bool {
        asset.chain == nil || asset.id == AssetBattery.Companion.shared.ID
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
}

enum EVMGaslessRelayerError: Error, Equatable {
    /// The emulated operation is gone: quote it again before sending.
    case quoteExpired
    /// The relayer answered something other than what it was asked for, or refused the operation.
    case rejected(reason: String)
    /// The signed operation is not the envelope `/gasless/send` takes.
    case malformedEnvelope(reason: String)
}

extension EVMGaslessRelayerError: LoggableError {
    var logDescription: String {
        switch self {
        case .quoteExpired:
            return "type=EVMGaslessRelayerError, case=quoteExpired"
        case let .rejected(reason):
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
    /// Builds the operation to sign with the fee taken in `assetId`.
    func emulate(wallet: Wallet, call: EVMGaslessCall, assetId: String) async throws -> EVMGaslessEmulation
    /// Hands the signed operation envelope, `{"operation": …}` as ChainKit writes it, to the relayer.
    /// An error other than an `EVMGaslessRelayerError` leaves the operation possibly broadcast.
    func send(wallet: Wallet, signedOperation: Data) async throws
}

/// The battery's gasless 2.0 relayer.
struct BatteryEVMGaslessRelayer: EVMGaslessRelaying {
    let service: BatteryGaslessService

    static let expiredErrorCodes: Set<String> = ["emulation_expired", "operation_not_found"]
    /// The answer to an operation sent before, whose first send may have landed.
    static let alreadySentErrorCode = "already_sent"

    func estimate(wallet: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        let payload = try call.payload
        let response = try await service.estimateGasless(
            wallet: wallet,
            request: Components.Schemas.GaslessV2EstimateRequest(
                chain_id: call.chainId,
                sender_address: call.sender,
                payload: payload
            )
        )
        return response.estimations.compactMap { estimation in
            guard let fee = estimation.fee,
                  fee._type == .value,
                  let amount = BigUInt(fee.data.amount)
            else {
                return nil
            }
            return EVMGaslessEstimation(asset: estimation.asset, fee: amount, isAvailable: estimation.available)
        }
    }

    func emulate(wallet: Wallet, call: EVMGaslessCall, assetId: String) async throws -> EVMGaslessEmulation {
        let payload = try call.payload
        let response = try await service.emulateGasless(
            wallet: wallet,
            request: Components.Schemas.GaslessV2EmulateRequest(
                chain_id: call.chainId,
                sender_address: call.sender,
                _type: call.kind.rawValue,
                gasless_asset: assetId,
                payloads: [payload]
            )
        )
        guard response.asset_id == assetId else {
            throw EVMGaslessRelayerError.rejected(reason: "emulated in \(response.asset_id), asked for \(assetId)")
        }
        guard response.fee._type == .value else {
            throw EVMGaslessRelayerError.rejected(reason: "unsupported emulation fee type: \(response.fee._type.rawValue)")
        }
        guard let fee = BigUInt(response.fee.data.amount) else {
            throw EVMGaslessRelayerError.rejected(reason: "emulation fee is not a number: \(response.fee.data.amount)")
        }
        let operationJSON: Data
        do {
            operationJSON = try JSONEncoder().encode(response.operation)
        } catch {
            throw EVMGaslessRelayerError.rejected(reason: "emulated operation cannot be written back: \(error.logDescription)")
        }
        let operation = try MultichainRelayedOperation(
            id: response.operation.id,
            json: String(decoding: operationJSON, as: UTF8.self)
        )
        return EVMGaslessEmulation(
            assetId: assetId,
            fee: fee,
            operation: operation,
            expiresAt: response.expires_at
        )
    }

    func send(wallet: Wallet, signedOperation: Data) async throws {
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
                throw EVMGaslessRelayerError.rejected(reason: "\(code): \(message)")
            }
            throw error
        }
        switch response.status {
        case .ok:
            return
        case .failed:
            throw EVMGaslessRelayerError.rejected(reason: "relayer answered `failed` to \(response.operation_id)")
        case .unknown:
            throw EVMGaslessUnknownSendStatus(operationId: response.operation_id)
        }
    }
}
