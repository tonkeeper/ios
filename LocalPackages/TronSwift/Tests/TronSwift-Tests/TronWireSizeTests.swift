import BigInt
import Foundation
@testable import TronSwift
@testable import TronSwiftAPI
import XCTest

final class TronWireSizeTests: XCTestCase {
    /// The layout model is checked against `raw_data` a node actually produced — the USDT trace the
    /// wire tests already carry — because that is the part a wrong assumption would silently skew.
    func test_rawDataLength_reproducesRealNodeRawData() {
        let rawData = Data(strictHex: Self.traceRawDataHex)

        XCTAssertEqual(
            TronWireSize.rawDataLength(
                expiration: 1_786_060_362_000,
                timestamp: 1_786_059_703_419,
                contractType: 31,
                typeUrlLength: "type.googleapis.com/protocol.TriggerSmartContract".utf8.count,
                contractValueLength: 116,
                feeLimit: 150_000_000
            ),
            rawData?.count
        )
    }

    /// The `triggerconstantcontract` probe is the same `raw_data` without its trailing `fee_limit`
    /// field, and the estimate is measured on the probe — so adding the field back has to land on
    /// the length the node produced for the transaction that is actually signed.
    func test_feeLimitFieldLength_closesTheGapBetweenTheProbeAndTheSignedTransaction() throws {
        let signedRawData = try XCTUnwrap(Data(strictHex: Self.traceRawDataHex))
        let probeRawData = signedRawData.dropLast(TronWireSize.feeLimitFieldLength(feeLimit: 150_000_000))

        XCTAssertEqual(probeRawData.count, 205)
        XCTAssertEqual(
            probeRawData.count + TronWireSize.feeLimitFieldLength(feeLimit: 150_000_000),
            signedRawData.count
        )
        XCTAssertEqual(TronApi.bandwidth(rawDataLength: signedRawData.count), 345)
    }

    func test_feeLimitFieldLength_isZeroForAFieldProtobufOmits() {
        XCTAssertEqual(TronWireSize.feeLimitFieldLength(feeLimit: 0), 0)
        XCTAssertEqual(TronWireSize.feeLimitFieldLength(feeLimit: 1), 3)
    }

    func test_nativeTransferRawDataLength_matchesTheLayout() {
        // 4 (ref_block_bytes) + 10 (ref_block_hash) + 7 (expiration) + 105 (contract) + 7 (timestamp)
        XCTAssertEqual(
            TronWireSize.nativeTransferRawDataLength(
                amountSun: 1_000_000,
                nowMilliseconds: 1_786_060_362_000
            ),
            133
        )
    }

    func test_nativeTransferRawDataLength_growsWithTheAmountVarint() {
        let small = TronWireSize.nativeTransferRawDataLength(
            amountSun: 1,
            nowMilliseconds: 1_786_060_362_000
        )
        let large = TronWireSize.nativeTransferRawDataLength(
            amountSun: UInt64(Int64.max),
            nowMilliseconds: 1_786_060_362_000
        )

        XCTAssertEqual(large - small, 8)
    }

    /// TRON charges `raw_data` + 3 (its field header) + 67 (a signature) + 64 (the largest result),
    /// spelled out here rather than assembled from the same constants the implementation uses.
    func test_nativeTransferBandwidth_matchesTheProtocolFormula() {
        XCTAssertEqual(TronApi.nativeTransferBandwidth(amountSun: BigUInt(1_000_000)), 267)
    }

    func test_rawDataEnvelopeLength_growsWithTheLengthVarint() {
        XCTAssertEqual(TronWireSize.rawDataEnvelopeLength(rawDataLength: 127), 2)
        XCTAssertEqual(TronWireSize.rawDataEnvelopeLength(rawDataLength: 128), 3)
        XCTAssertEqual(TronWireSize.rawDataEnvelopeLength(rawDataLength: 16383), 3)
        XCTAssertEqual(TronWireSize.rawDataEnvelopeLength(rawDataLength: 16384), 4)
    }

    func test_nativeTransferBandwidth_clampsAnAmountWiderThanTheProtocolAllows() {
        XCTAssertEqual(
            TronApi.nativeTransferBandwidth(amountSun: BigUInt(2).power(80)),
            TronApi.nativeTransferBandwidth(amountSun: BigUInt(UInt64.max))
        )
    }

    private static let traceRawDataHex =
        "0a02f96c2208f0006781f475a6424090a2f9cbfd335aae01081f12a9010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412740a15416bda46f57114c4c3a2617c2ad3b1722d81360df4121541a614f803b6fd780986a42c78ec9c7f77e6ded13c2244a9059cbb0000000000000000000000006bda46f57114c4c3a2617c2ad3b1722d81360df400000000000000000000000000000000000000000000000000000000002dc6c070fb88d1cbfd33900180a3c347"
}
