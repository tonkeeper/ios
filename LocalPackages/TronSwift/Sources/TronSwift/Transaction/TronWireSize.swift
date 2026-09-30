import Foundation

/// Size of a `Transaction.raw_data` derived from the protobuf layout, so a bandwidth estimate does
/// not need the node to build a throwaway transaction first.
public enum TronWireSize {
    private static let addressLength = 21
    private static let refBlockBytesLength = 2
    private static let refBlockHashLength = 8

    /// `wallet/createtransaction` fills `ref_block_*` from the current head and `timestamp` from its
    /// own clock, so the only field whose encoded width depends on the caller is `amount`. Millisecond
    /// timestamps have occupied six varint bytes since 1971 and will until 2109, and `expiration` sits
    /// a minute past `timestamp` — near enough that the pair cannot straddle that boundary in practice.
    public static func nativeTransferRawDataLength(
        amountSun: UInt64,
        nowMilliseconds: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Int {
        let transferContract = lengthDelimitedField(fieldNumber: 1, payloadLength: addressLength)
            + lengthDelimitedField(fieldNumber: 2, payloadLength: addressLength)
            + varintField(fieldNumber: 3, value: amountSun)

        let now = UInt64(max(nowMilliseconds, 0))
        return rawDataLength(
            expiration: now,
            timestamp: now,
            contractType: TronContractType.transfer.rawValue,
            typeUrlLength: TronContractType.transfer.typeURL.utf8.count,
            contractValueLength: transferContract,
            feeLimit: nil
        )
    }

    /// `raw_data` as field 1 of the signed `Transaction`: the tag plus a length varint, which is
    /// two bytes once `raw_data` passes 127 — every transfer does.
    public static func rawDataEnvelopeLength(rawDataLength: Int) -> Int {
        lengthDelimitedField(fieldNumber: 1, payloadLength: rawDataLength) - rawDataLength
    }

    /// `fee_limit` as field 18 of `raw_data`. A `triggerconstantcontract` probe never carries it
    /// while the signed transaction built from `triggersmartcontract` always does, so an estimate
    /// measured on the probe has to add it back. Zero is not on the wire at all — protobuf omits a
    /// scalar left at its default, which `test_verify_acceptsAnOmittedZeroFeeLimit` pins.
    public static func feeLimitFieldLength(feeLimit: UInt64) -> Int {
        guard feeLimit > 0 else { return 0 }
        return varintField(fieldNumber: 18, value: feeLimit)
    }

    static func rawDataLength(
        expiration: UInt64,
        timestamp: UInt64,
        contractType: UInt64,
        typeUrlLength: Int,
        contractValueLength: Int,
        feeLimit: UInt64?
    ) -> Int {
        let parameter = lengthDelimitedField(fieldNumber: 1, payloadLength: typeUrlLength)
            + lengthDelimitedField(fieldNumber: 2, payloadLength: contractValueLength)

        let contract = varintField(fieldNumber: 1, value: contractType)
            + lengthDelimitedField(fieldNumber: 2, payloadLength: parameter)

        return lengthDelimitedField(fieldNumber: 1, payloadLength: refBlockBytesLength)
            + lengthDelimitedField(fieldNumber: 4, payloadLength: refBlockHashLength)
            + varintField(fieldNumber: 8, value: expiration)
            + lengthDelimitedField(fieldNumber: 11, payloadLength: contract)
            + varintField(fieldNumber: 14, value: timestamp)
            + (feeLimit.map { varintField(fieldNumber: 18, value: $0) } ?? 0)
    }

    private static func varintField(fieldNumber: UInt32, value: UInt64) -> Int {
        ProtobufWire.tag(fieldNumber: fieldNumber, wireType: 0).count
            + ProtobufWire.encodeVarint(value).count
    }

    private static func lengthDelimitedField(fieldNumber: UInt32, payloadLength: Int) -> Int {
        ProtobufWire.tag(fieldNumber: fieldNumber, wireType: 2).count
            + ProtobufWire.encodeVarint(UInt64(payloadLength)).count
            + payloadLength
    }
}
