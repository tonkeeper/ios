import Foundation
import SwapAPI

public struct MultichainSwapPreparedPayload: Sendable, Hashable {
    public var payloadId: String
    public var kind: String
    public var chainId: String
    public var chainFamily: String
    public var payloadType: String
    public var payload: String
    public var humanSummary: MultichainSwapHumanSummary
    public var validationStatus: String
    public var dateExpire: Date
    /// `nil` when the backend did not say; older responses predate the field.
    public var calldataPayloadType: MultichainSwapCalldataPayloadType?

    public init(
        payloadId: String,
        kind: String,
        chainId: String,
        chainFamily: String,
        payloadType: String,
        payload: String,
        humanSummary: MultichainSwapHumanSummary,
        validationStatus: String,
        dateExpire: Date,
        calldataPayloadType: MultichainSwapCalldataPayloadType? = nil
    ) {
        self.payloadId = payloadId
        self.kind = kind
        self.chainId = chainId
        self.chainFamily = chainFamily
        self.payloadType = payloadType
        self.payload = payload
        self.humanSummary = humanSummary
        self.validationStatus = validationStatus
        self.dateExpire = dateExpire
        self.calldataPayloadType = calldataPayloadType
    }
}

extension MultichainSwapPreparedPayload {
    init(api: SwapAPI.Components.Schemas.CrossSwapPayload) {
        self.init(
            payloadId: api.payload_id,
            kind: api.kind.rawValue,
            chainId: api.chain_id,
            chainFamily: api.chain_family.rawValue,
            payloadType: api.payload_type.rawValue,
            payload: api.payload,
            humanSummary: MultichainSwapHumanSummary(api: api.human_summary),
            validationStatus: api.validation_status.rawValue,
            dateExpire: api.date_expire,
            calldataPayloadType: api.calldata_payload_type.map(MultichainSwapCalldataPayloadType.init(api:))
        )
    }
}
