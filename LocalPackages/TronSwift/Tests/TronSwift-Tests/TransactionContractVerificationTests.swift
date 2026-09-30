import BigInt
import Foundation
@testable import TronSwift
import XCTest

final class TransactionContractVerificationTests: XCTestCase {
    /// The USDT transfer from the TK-2909 trace, the node's own bytes: 3 USDT to the sender's own
    /// address, `fee_limit` exactly as requested.
    private static let traceRawDataHex =
        "0a02f96c2208f0006781f475a6424090a2f9cbfd335aae01081f12a9010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412740a15416bda46f57114c4c3a2617c2ad3b1722d81360df4121541a614f803b6fd780986a42c78ec9c7f77e6ded13c2244a9059cbb0000000000000000000000006bda46f57114c4c3a2617c2ad3b1722d81360df400000000000000000000000000000000000000000000000000000000002dc6c070fb88d1cbfd33900180a3c347"
    private static let traceExpiration: Int64 = 1_786_060_362_000
    private static let traceOwnerHex = "416bda46f57114c4c3a2617c2ad3b1722d81360df4"
    private static let traceAmount = BigUInt(3_000_000)
    private static let traceFeeLimit = 150_000_000

    private static let otherAddressHex = "41a614f803b6fd780986a42c78ec9c7f77e6ded13d"

    // MARK: - What the node actually sent

    func test_verify_acceptsTheTransferTheNodeWasAskedToBuild() throws {
        try Self.transaction(rawDataHex: Self.traceRawDataHex).verify(matches: Self.traceExpectation())
    }

    /// Extending the expiration is the one local rewrite a built transaction goes through before it
    /// is signed, so a verified transaction has to stay verified across it.
    func test_verify_acceptsTheSameTransferAfterExtendingExpiration() throws {
        let extended = try Self.transaction(rawDataHex: Self.traceRawDataHex)
            .extendingExpiration(byMilliseconds: 600_000)

        try extended.verify(matches: Self.traceExpectation())
    }

    func test_verify_acceptsANativeTransfer() throws {
        let transaction = Self.transaction(rawDataHex: Self.nativeRawDataHex())

        try transaction.verify(
            matches: .nativeTransfer(
                owner: Self.address(Self.traceOwnerHex),
                to: Self.address(Self.otherAddressHex),
                amountSun: 1000
            )
        )
    }

    // MARK: - A node answering with something else

    func test_verify_rejectsARecipientSwappedInsideTheCallData() {
        let hijacked = TransferMethod(to: Self.address(Self.otherAddressHex), amount: Self.traceAmount)

        Self.assertMismatch(
            .callData,
            in: Self.triggerRawDataHex(data: hijacked.encode()),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsADifferentTokenContract() {
        Self.assertMismatch(
            .contractAddress,
            in: Self.triggerRawDataHex(contract: Self.address(Self.otherAddressHex).raw),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsADifferentOwner() {
        Self.assertMismatch(
            .ownerAddress,
            in: Self.triggerRawDataHex(owner: Self.address(Self.otherAddressHex).raw),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsAFeeLimitAboveTheRequestedOne() {
        Self.assertMismatch(
            .feeLimit,
            in: Self.triggerRawDataHex(feeLimit: 1_000_000_000),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_acceptsAnOmittedZeroFeeLimit() throws {
        try Self.transaction(rawDataHex: Self.triggerRawDataHex(feeLimit: nil)).verify(
            matches: Self.traceExpectation(feeLimit: 0)
        )
    }

    func test_verify_rejectsANegativeExpectedFeeLimit() {
        Self.assertMismatch(
            .feeLimit,
            in: Self.triggerRawDataHex(),
            matching: Self.traceExpectation(feeLimit: -1)
        )
    }

    func test_verify_rejectsASecondContractRidingAlong() {
        Self.assertMismatch(
            .contractCount(2),
            in: Self.triggerRawDataHex(contractRepeats: 2),
            matching: Self.traceExpectation()
        )
    }

    /// `call_value` would send TRX along with the token transfer shown on the confirmation screen.
    func test_verify_rejectsTrxAttachedToTheCall() {
        Self.assertMismatch(
            .unexpectedField(number: 3),
            in: Self.triggerRawDataHex(extraCallFields: Wire.varint(3, 1_000_000)),
            matching: Self.traceExpectation()
        )
    }

    /// `Permission_id` picks a different authorization than the key the app signs with.
    func test_verify_rejectsAPermissionId() {
        Self.assertMismatch(
            .unexpectedField(number: 5),
            in: Self.triggerRawDataHex(extraContractFields: Wire.varint(5, 2)),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsATypeURLThatDoesNotMatchTheContract() {
        Self.assertMismatch(
            .typeURL,
            in: Self.triggerRawDataHex(typeURL: TronContractType.transfer.typeURL),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsAContractTypeTheRequestDidNotAskFor() {
        Self.assertMismatch(
            .contractType,
            in: Self.traceRawDataHex,
            matching: .nativeTransfer(
                owner: Self.address(Self.traceOwnerHex),
                to: Self.address(Self.otherAddressHex),
                amountSun: Self.traceAmount
            )
        )
    }

    func test_verify_rejectsADuplicateFeeLimit() {
        Self.assertMismatch(
            .malformedRawData,
            in: Self.triggerRawDataHex(extraRawDataFields: Wire.varint(18, UInt64(Self.traceFeeLimit))),
            matching: Self.traceExpectation()
        )
    }

    func test_verify_rejectsMalformedRawDataHex() {
        Self.assertMismatch(.malformedRawData, in: "0a02f96c4090a2f9cbfd337", matching: Self.traceExpectation())
    }

    // MARK: - A node answering with something else, native transfer

    func test_verify_rejectsADifferentNativeAmount() {
        Self.assertMismatch(
            .amount,
            in: Self.nativeRawDataHex(amountSun: 999),
            matching: Self.nativeExpectation()
        )
    }

    func test_verify_rejectsADifferentNativeRecipient() {
        Self.assertMismatch(
            .toAddress,
            in: Self.nativeRawDataHex(to: Self.address(Self.traceOwnerHex).raw),
            matching: Self.nativeExpectation()
        )
    }

    /// `createtransaction` sets no `fee_limit`, so one appearing is a field nothing compared.
    func test_verify_rejectsAFeeLimitOnANativeTransfer() {
        Self.assertMismatch(
            .feeLimit,
            in: Self.nativeRawDataHex(feeLimit: 150_000_000),
            matching: Self.nativeExpectation()
        )
    }

    // MARK: - Fixtures

    private static func assertMismatch(
        _ expected: Transaction.ContractMismatch,
        in rawDataHex: String,
        matching contract: Transaction.ExpectedContract,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try transaction(rawDataHex: rawDataHex).verify(matches: contract), file: file, line: line) {
            XCTAssertEqual($0 as? Transaction.ContractMismatch, expected, file: file, line: line)
        }
    }

    private static func traceExpectation(feeLimit: Int = traceFeeLimit) -> Transaction.ExpectedContract {
        .smartContractCall(
            owner: address(traceOwnerHex),
            contract: USDT.address,
            data: TransferMethod(to: address(traceOwnerHex), amount: traceAmount).encode(),
            feeLimit: feeLimit
        )
    }

    private static func nativeExpectation() -> Transaction.ExpectedContract {
        .nativeTransfer(owner: address(traceOwnerHex), to: address(otherAddressHex), amountSun: 1000)
    }

    private static func address(_ hex: String) -> Address {
        try! Address(raw: Data(ProtobufWire.decodeHex(hex)))
    }

    private static func triggerRawDataHex(
        owner: Data = address(traceOwnerHex).raw,
        contract: Data = USDT.address.raw,
        data: Data = TransferMethod(to: address(traceOwnerHex), amount: traceAmount).encode(),
        feeLimit: UInt64? = UInt64(traceFeeLimit),
        typeURL: String = TronContractType.triggerSmartContract.typeURL,
        contractRepeats: Int = 1,
        extraCallFields: [UInt8] = [],
        extraContractFields: [UInt8] = [],
        extraRawDataFields: [UInt8] = []
    ) -> String {
        let call = Wire.bytes(1, [UInt8](owner))
            + Wire.bytes(2, [UInt8](contract))
            + Wire.bytes(4, [UInt8](data))
            + extraCallFields
        let record = contractRecord(
            type: .triggerSmartContract,
            typeURL: typeURL,
            value: call,
            extraFields: extraContractFields
        )
        return rawDataHex(
            contracts: Array(repeating: record, count: contractRepeats),
            feeLimit: feeLimit,
            extraFields: extraRawDataFields
        )
    }

    private static func nativeRawDataHex(
        owner: Data = address(traceOwnerHex).raw,
        to: Data = address(otherAddressHex).raw,
        amountSun: UInt64 = 1000,
        feeLimit: UInt64? = nil
    ) -> String {
        let transfer = Wire.bytes(1, [UInt8](owner))
            + Wire.bytes(2, [UInt8](to))
            + Wire.varint(3, amountSun)
        let record = contractRecord(
            type: .transfer,
            typeURL: TronContractType.transfer.typeURL,
            value: transfer,
            extraFields: []
        )
        return rawDataHex(contracts: [record], feeLimit: feeLimit, extraFields: [])
    }

    private static func contractRecord(
        type: TronContractType,
        typeURL: String,
        value: [UInt8],
        extraFields: [UInt8]
    ) -> [UInt8] {
        let parameter = Wire.bytes(1, [UInt8](typeURL.utf8)) + Wire.bytes(2, value)
        return Wire.varint(1, type.rawValue) + Wire.bytes(2, parameter) + extraFields
    }

    private static func rawDataHex(contracts: [[UInt8]], feeLimit: UInt64?, extraFields: [UInt8]) -> String {
        var bytes = Wire.bytes(1, [0xF9, 0x6C])
            + Wire.varint(8, UInt64(traceExpiration))
        for contract in contracts {
            bytes += Wire.bytes(11, contract)
        }
        bytes += Wire.varint(14, UInt64(traceExpiration - 60000))
        if let feeLimit {
            bytes += Wire.varint(18, feeLimit)
        }
        return Data(bytes + extraFields).hexString()
    }

    private static func transaction(rawDataHex: String) -> Transaction {
        Transaction(
            isVisible: true,
            txID: "",
            rawDataHex: rawDataHex,
            rawData: Transaction.RawData(json: [:], expiration: traceExpiration),
            signature: nil
        )
    }

    private enum Wire {
        static func varint(_ field: UInt32, _ value: UInt64) -> [UInt8] {
            ProtobufWire.tag(fieldNumber: field, wireType: 0) + ProtobufWire.encodeVarint(value)
        }

        static func bytes(_ field: UInt32, _ payload: [UInt8]) -> [UInt8] {
            ProtobufWire.tag(fieldNumber: field, wireType: 2)
                + ProtobufWire.encodeVarint(UInt64(payload.count))
                + payload
        }
    }
}
