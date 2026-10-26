import BigInt
@testable import KeeperCore
import TronSwift
import XCTest

final class PerpsDepositCalldataTests: XCTestCase {
    private let token = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    private let spender = "0x00000000000000000000000000000000000000ab"
    private let beneficiary = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"

    func testTronApprovalSpenderUsesABIAddressAndPreservesBase58Case() throws {
        let token = "TR7NHqjeKQxGTCi8q8ZY4pL8otgjLj6t"
        let tronSpender = "TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7"
        let raw = try TronSwift.Address(address: tronSpender).notPrefixed().map { String(format: "%02x", $0) }.joined()
        let approved = try PerpsDepositCalldata.readApproval(payload(to: token, data: approve(spender: "0x" + raw, amount: 2_500_000)), token: token, spender: tronSpender, amountUnits: 2_500_000)
        XCTAssertEqual(approved.spender, "0x" + raw)
    }

    func testAnApprovalForExactlyTheQuotedAmountIsRead() throws {
        let approved = try PerpsDepositCalldata.readApproval(
            payload(data: approve(spender: spender, amount: 2_500_000)),
            token: token,
            spender: spender,
            amountUnits: BigUInt(2_500_000)
        )

        XCTAssertEqual(approved, PerpsDepositCalldata.ApprovedSpending(spender: spender, amountUnits: 2_500_000))
    }

    func testABudgetedApprovalStillChecksTokenAndSpender() {
        let foreign = "0x000000000000000000000000000000000000dead"
        XCTAssertThrowsError(try PerpsDepositCalldata.readApproval(
            payload(to: foreign, data: approve(spender: spender, amount: 2_490_000)),
            token: token,
            spender: spender,
            amountUnits: 2_500_000,
            exactAmount: false
        )) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, .approvalTokenMismatch(payloadId: "p_approve", to: foreign))
        }
        XCTAssertThrowsError(try PerpsDepositCalldata.readApproval(
            payload(data: approve(spender: foreign, amount: 2_490_000)),
            token: token,
            spender: spender,
            amountUnits: 2_500_000,
            exactAmount: false
        )) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, .approvalSpenderMismatch(payloadId: "p_approve", spender: foreign))
        }
    }

    /// The spender is written in the calldata, the gateway is named by the payload that
    /// follows it; a quote that disagrees about which contract may pull the tokens is not
    /// signed, whichever of the two is the honest one.
    func testAnApprovalForAnotherSpenderIsRefused() {
        let foreign = "0x000000000000000000000000000000000000dead"

        assertRefused(
            payload(data: approve(spender: foreign, amount: 2_500_000)),
            amountUnits: 2_500_000,
            .approvalSpenderMismatch(payloadId: "p_approve", spender: foreign)
        )
    }

    func testAnUnlimitedAllowanceIsRefused() {
        let unlimited = BigUInt(2).power(256) - 1

        assertRefused(
            payload(data: approve(spender: spender, amount: unlimited)),
            amountUnits: 2_500_000,
            .approvalAmountMismatch(payloadId: "p_approve", amount: unlimited.description)
        )
    }

    func testAnApprovalOnAnotherContractThanTheSourceTokenIsRefused() {
        let other = "0x000000000000000000000000000000000000beef"

        assertRefused(
            payload(to: other, data: approve(spender: spender, amount: 2_500_000)),
            amountUnits: 2_500_000,
            .approvalTokenMismatch(payloadId: "p_approve", to: other)
        )
    }

    func testACallThatIsNotAnApprovalIsRefused() {
        assertRefused(
            payload(data: "0xdeadbeef"),
            amountUnits: 2_500_000,
            .notAnApproval(payloadId: "p_approve")
        )
    }

    func testAnAddressWordWithSomethingInItsPaddingIsNotAnAddress() {
        let padded = "0x" + PerpsDepositCalldata.approveSelector
            + "0000000000000000000000ff" + spender.dropFirst(2)
            + word(BigUInt(2_500_000))

        assertRefused(payload(data: padded), amountUnits: 2_500_000, .malformedCall(payloadId: "p_approve"))
    }

    func testAGatewayCallHasToBeACall() {
        XCTAssertThrowsError(try checkGateway(payload(data: nil))) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, .missingCall(payloadId: "p_approve"))
        }
        XCTAssertThrowsError(try checkGateway(payload(data: "0xabc"))) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, .malformedCall(payloadId: "p_approve"))
        }
        XCTAssertNoThrow(try checkGateway(payload(to: PerpsDepositCalldata.gatewayAddress, data: depositCalldata())))
    }

    func testGatewayCallRejectsAnythingOtherThanTheReviewedDeposit() {
        let gateway = PerpsDepositCalldata.gatewayAddress
        let other = "0x000000000000000000000000000000000000dead"
        let unsafe = [
            payload(to: other, data: depositCalldata()),
            payload(to: gateway, data: depositCalldata(selector: "a9059cbb")),
            payload(to: gateway, data: depositCalldata(receiver: other)),
            payload(to: gateway, data: depositCalldata(assetIndex: 1)),
            payload(to: gateway, data: depositCalldata(routeType: 1)),
            payload(to: gateway, data: depositCalldata(amount: 3_000_000)),
            payload(to: gateway, data: depositCalldata() + word(0)),
        ]
        for call in unsafe {
            XCTAssertThrowsError(try checkGateway(call)) { error in
                XCTAssertEqual(error as? PerpsDepositCalldataError, .unsafeGatewayCall(payloadId: call.payloadId))
            }
        }
    }

    private func checkGateway(_ call: PerpsDepositQuotePayload) throws {
        try PerpsDepositCalldata.checkGatewayCall(call, beneficiary: beneficiary, amountUnits: 2_500_000)
    }

    func testAFoldedApprovalAndPaymentAreReadAsTheirTwoCalls() throws {
        let approve = HermesBatchFixture.approve(spender: spender, amountUnits: "2500000")
        let batch = payload(to: account, data: HermesBatchFixture.execute([(token, approve), (spender, "0xdeadbeef")]))

        let calls = try PerpsDepositCalldata.readBatch(batch)

        XCTAssertEqual(calls.map(\.to), [token, spender])
        XCTAssertEqual(calls.map(\.data), [approve, "0xdeadbeef"])
        XCTAssertEqual(calls.map(\.valueUnits), ["0", "0"])
        XCTAssertEqual(try PerpsDepositCalldata.readApproval(calls[0], token: token, spender: spender, amountUnits: 2_500_000).amountUnits, 2_500_000)
    }

    /// chain-kit's `HermesTest` vector, encoded by ethers: approve plus a router call carrying
    /// 0.25 ETH. Read as the contract reads it, the coin it spends is what refuses it.
    func testAnEthersEncodedBatchIsReadAndItsCoinSpendingCallRefused() {
        let vector = "0xe9ae5c53" + PerpsDepositCalldata.plainBatchMode
            + "0000000000000000000000000000000000000000000000000000000000000040"
            + "0000000000000000000000000000000000000000000000000000000000000200"
            + "0000000000000000000000000000000000000000000000000000000000000020"
            + "0000000000000000000000000000000000000000000000000000000000000002"
            + "0000000000000000000000000000000000000000000000000000000000000040"
            + "0000000000000000000000000000000000000000000000000000000000000120"
            + "000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
            + "0000000000000000000000000000000000000000000000000000000000000000"
            + "0000000000000000000000000000000000000000000000000000000000000060"
            + "0000000000000000000000000000000000000000000000000000000000000044"
            + "095ea7b30000000000000000000000003b4d794a66304f130a4db8f2551b0070"
            + "dfcf5ca700000000000000000000000000000000000000000000000000000000"
            + "000f424000000000000000000000000000000000000000000000000000000000"
            + "0000000000000000000000003b4d794a66304f130a4db8f2551b0070dfcf5ca7"
            + "00000000000000000000000000000000000000000000000003782dace9d90000"
            + "0000000000000000000000000000000000000000000000000000000000000060"
            + "0000000000000000000000000000000000000000000000000000000000000004"
            + "deadbeef00000000000000000000000000000000000000000000000000000000"

        assertBatchRefused(payload(to: account, data: vector), .unsafeBatch(payloadId: "p_approve"))
    }

    func testABatchCallingBackIntoTheAccountIsRefused() {
        let data = HermesBatchFixture.execute([(token, "0x"), (account, "0xdeadbeef")])

        assertBatchRefused(payload(to: account, data: data), .unsafeBatch(payloadId: "p_approve"))
    }

    func testARelayedBatchIsNotReadAsAPlainOne() {
        let relayed = "0100000000007821000100000000000000000000000000000000000000000000"
        let data = HermesBatchFixture.execute([(token, "0x")], mode: relayed)

        assertBatchRefused(payload(to: account, data: data), .notABatch(payloadId: "p_approve"))
    }

    func testABatchCarryingBytesItsCallsDoNotAccountForIsRefused() {
        let data = HermesBatchFixture.execute([(token, "0x"), (spender, "0xdeadbeef")]) + String(repeating: "0", count: 64)

        assertBatchRefused(payload(to: account, data: data), .malformedCall(payloadId: "p_approve"))
    }

    private let account = "0x2e1fa1b0c7dd3a9b6f4c55e8d11aa9c0b3e7f218"

    private func assertBatchRefused(
        _ payload: PerpsDepositQuotePayload,
        _ expected: PerpsDepositCalldataError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try PerpsDepositCalldata.readBatch(payload), file: file, line: line) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, expected, file: file, line: line)
        }
    }

    private func assertRefused(
        _ payload: PerpsDepositQuotePayload,
        amountUnits: BigUInt,
        _ expected: PerpsDepositCalldataError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try PerpsDepositCalldata.readApproval(
                payload,
                token: token,
                spender: spender,
                amountUnits: amountUnits
            ),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? PerpsDepositCalldataError, expected, file: file, line: line)
        }
    }

    private func payload(to: String? = nil, data: String?) -> PerpsDepositQuotePayload {
        PerpsDepositQuotePayload(
            payloadId: "p_approve",
            kind: .approval,
            chainId: "eth/mainnet",
            to: to ?? token,
            valueUnits: "0",
            data: data,
            mode: nil,
            gasLimitUnits: nil,
            delegation: nil
        )
    }

    private func approve(spender: String, amount: BigUInt) -> String {
        "0x" + PerpsDepositCalldata.approveSelector
            + String(repeating: "0", count: 24) + spender.dropFirst(2)
            + word(amount)
    }

    private func depositCalldata(
        selector: String = PerpsDepositCalldata.depositSelector,
        receiver: String? = nil,
        assetIndex: BigUInt = 3,
        routeType: BigUInt = 0,
        amount: BigUInt = 2_500_000
    ) -> String {
        "0x" + selector
            + String(repeating: "0", count: 24) + (receiver ?? beneficiary).dropFirst(2)
            + word(assetIndex) + word(routeType) + word(amount)
    }

    private func word(_ value: BigUInt) -> String {
        let hex = String(value, radix: 16)
        return String(repeating: "0", count: 64 - hex.count) + hex
    }
}
