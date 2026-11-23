@preconcurrency import BigInt
@preconcurrency import ChainKit
import Foundation
import SwapAPI

/// Why a route prepared on `/v3` is not signed.
enum MultichainSwapPreparedOperationError: Error, Equatable {
    /// The backend has not finished validating the route: preparing it again may pass.
    case pending
    /// The backend's validation rejected the route.
    case rejected
    /// chain-kit cannot read the operation as the backend sent it, so there is nothing to sign.
    case unreadable(String)
}

/// A route prepared on `/v3/crosschain`: chain-kit's operation, signed as it stands — approvals
/// first, the swap last — and the swap as the backend sums it up.
struct MultichainSwapPreparedOperation: Sendable {
    let operation: ChainKit.Operation
    let routeId: String
    let providerRouteId: String?
    let aggregator: String
    let executionId: String?
    /// Where the swap's deposit goes, when the route pays a deposit address rather than a contract.
    let depositAddress: String?
    /// What the swap receives, in the bought asset's base units, when the backend states it.
    let receiveAmount: BigUInt?
    /// The least the swap receives, in the bought asset's base units, when the backend states it.
    let minimumReceiveAmount: BigUInt?
    /// When the first of its payloads stops being signable.
    let expiresAt: Date

    init(_ prepared: SwapAPI.Components.Schemas.CrossSwapPrepareV3) throws(MultichainSwapPreparedOperationError) {
        switch prepared.validation_status {
        case .validated:
            break
        case .pending:
            throw .pending
        case .rejected:
            throw .rejected
        }
        operation = try Self.parse(prepared.operation)
        routeId = prepared.route_id
        providerRouteId = prepared.provider_route_id
        aggregator = prepared.aggregator.rawValue
        executionId = prepared.execution_id
        let summary = prepared.human_summary
        depositAddress = summary.deposit_address.flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
        receiveAmount = Self.units(summary.receive_amount)
        minimumReceiveAmount = Self.units(summary.minimum_receive_amount)
        expiresAt = prepared.date_expire
    }
}

extension MultichainSwapRoute {
    /// The route as its prepared operation receives, since the backend may reprice between quote
    /// and build: a least the operation does not state, and a price impact the quote states, move
    /// with what the route now receives; the least is never above it, and a price impact the quote
    /// leaves out stays out.
    func prepared(as prepared: MultichainSwapPreparedOperation) -> MultichainSwapRoute {
        var route = self
        route.providerRouteId = prepared.providerRouteId ?? providerRouteId
        guard let quoted = BigUInt(estimatedDestinationAmount), let quotedMinimum = BigUInt(minimumDestinationAmount) else {
            return route
        }
        let receives = prepared.receiveAmount ?? quoted
        let minimum = prepared.minimumReceiveAmount ?? (quoted > 0 ? quotedMinimum * receives / quoted : quotedMinimum)
        route.estimatedDestinationAmount = receives.description
        route.minimumDestinationAmount = min(minimum, receives).description
        route.valueDifferenceBps = valueDifferenceBps.flatMap { bps in
            quoted > 0 ? Int(exactly: (BigInt(bps) + 10000) * BigInt(receives) / BigInt(quoted) - 10000) : bps
        }
        return route
    }
}

private extension MultichainSwapPreparedOperation {
    /// chain-kit reads these from their digits, but the client holds a JSON number as an `Int` or a
    /// `Double` and writes it back from that: such an amount may not reach chain-kit as it was sent.
    static let amountKeys: Set = ["value", "amount", "limit", "price", "max_fee_per_gas", "max_priority_fee_per_gas"]

    static func parse(
        _ operation: SwapAPI.Components.Schemas.GenericOperation
    ) throws(MultichainSwapPreparedOperationError) -> ChainKit.Operation {
        guard let id = operation.value["id"] as? String else {
            throw .unreadable("no operation id")
        }
        if let key = numericAmount(in: operation.value) {
            throw .unreadable("\(key) is a JSON number")
        }
        let encoder = JSONEncoder()
        // The same operation then reads as the same meta, which its review's id is made of.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try ChainKitOperationSender.parse(id: id, payloads: String(decoding: encoder.encode(operation), as: UTF8.self))
        } catch {
            throw .unreadable(String(describing: error))
        }
    }

    static func numericAmount(in value: (any Sendable)?, key: String? = nil) -> String? {
        switch value {
        case let object as [String: (any Sendable)?]:
            object.lazy.compactMap { numericAmount(in: $0.value, key: $0.key) }.first
        case let array as [(any Sendable)?]:
            array.lazy.compactMap { numericAmount(in: $0) }.first
        case is Int, is Double:
            key.flatMap { amountKeys.contains($0) ? $0 : nil }
        default:
            nil
        }
    }

    /// Smallest units as the API writes them: digits only, where `BigUInt` alone takes a sign and
    /// reads "" as 0.
    static func units(_ value: String?) -> BigUInt? {
        guard let value, !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return BigUInt(value)
    }
}
