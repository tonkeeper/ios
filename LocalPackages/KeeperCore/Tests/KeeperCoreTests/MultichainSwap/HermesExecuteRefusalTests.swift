import BigInt
@testable import KeeperCore
import XCTest

final class HermesExecuteRefusalTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let deadline = "1790000600"
    private let batteryMode = "0x0100000000007821000100000000000000000000000000000000000000000000"
    private let tokenMode = "0x0101000000007821000100000000000000000000000000000000000000000029"
    private let feeRecipient = "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d"
    private let foreign = "0x000000000000000000000000000000000000dead"

    private var asked: [HermesExecute.Call] {
        [HermesExecute.Call(target: GaslessFixtures.usdtContract, value: "0", data: GaslessFixtures.usdtTransfer)]
    }

    func testTheModesTheRelayerRunsCallsInAreBatchesOfTheDelegatesOwnSelector() {
        XCTAssertEqual(HermesExecute.execution(ofRelayedMode: batteryMode), .default)
        for mode in [tokenMode, "0x0101000000007821000100000000000000000000000000000000000000000009"] {
            XCTAssertEqual(HermesExecute.execution(ofRelayedMode: mode), .try, mode)
        }
        let refused = [
            ("a plain batch the account runs itself", "0x01" + String(repeating: "0", count: 62)),
            ("default execution with policy bits", String(batteryMode.dropLast(2)) + "29"),
            ("a single call", "0x0000000000007821000100000000000000000000000000000000000000000000"),
            ("another execution type", "0x0102000000007821000100000000000000000000000000000000000000000000"),
            ("bits before the selector", "0x0100000100007821000100000000000000000000000000000000000000000000"),
            ("a word cut short", String(batteryMode.dropLast(2))),
        ]
        for (name, mode) in refused {
            XCTAssertNil(HermesExecute.execution(ofRelayedMode: mode), name)
        }
    }

    func testChargesPayForExactlyTheCallsAskedRunByDefault() throws {
        XCTAssertNil(try refusal(relayed(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)]), fee: .battery))

        XCTAssertNotNil(try refusal(relayed(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], mode: tokenMode), fee: .battery))
        let token = HermesExecute.Fee.token(contract: GaslessFixtures.usdtContract, amount: 100)
        XCTAssertNotNil(try refusal(relayed(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)]), fee: token))
    }

    func testAFeeInATokenIsOneTransferOfThatTokenFirstOfNoMoreThanTheFee() throws {
        let fee = HermesExecute.Fee.token(contract: GaslessFixtures.usdtContract, amount: 115_304)
        let paid = try relayed(calls: [(GaslessFixtures.usdtContract, transfer(115_304)), (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], mode: tokenMode)
        XCTAssertNil(refusal(paid, fee: fee))

        let refused: [(String, [(target: String, data: String)], HermesExecute.Fee)] = [
            ("a fee over the priced one", [(GaslessFixtures.usdtContract, transfer(115_305)), (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], fee),
            ("a fee in another token", [(foreign, transfer(115_304)), (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], fee),
            ("a fee transfer when charges pay", [(GaslessFixtures.usdtContract, transfer(115_304)), (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], .battery),
            ("a fee transfer after the calls", [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer), (GaslessFixtures.usdtContract, transfer(115_304))], fee),
            ("two fee transfers", [(GaslessFixtures.usdtContract, transfer(1)), (GaslessFixtures.usdtContract, transfer(1)), (GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], fee),
            ("another call", [(foreign, GaslessFixtures.usdtTransfer)], fee),
            ("no fee transfer", [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], fee),
            ("no call", [], fee),
        ]
        for (name, calls, fee) in refused {
            XCTAssertNotNil(try refusal(relayed(calls: calls, mode: tokenMode), fee: fee), name)
        }
    }

    func testOnlyOneDelegationToHermesOnTheChainItselfIsSigned() throws {
        let calls = [(target: GaslessFixtures.usdtContract, data: GaslessFixtures.usdtTransfer)]
        let elsewhere = #"{ "address": "\#(foreign)", "nonce": 41, "chainId": 1 }"#
        let otherChain = #"{ "address": "0x24b576BC271823bF9C24BE627B4363b9b00191e9", "nonce": 41, "chainId": 56 }"#
        for meta in [elsewhere, otherChain] {
            XCTAssertNotNil(try refusal(relayed(calls: calls, authorizationMeta: meta), fee: .battery), meta)
        }
        XCTAssertNotNil(try refusal(twoAuthorizations(), fee: .battery))
    }

    func testAnOperationForAnotherChainIsNotSigned() throws {
        let operation = try relayed(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)])

        let reason = HermesExecute.refusal(of: operation, calls: asked, chain: .bsc, owner: GaslessFixtures.sender, fee: .battery, now: now)

        XCTAssertNotNil(reason)
    }

    func testAnExecuteInAnotherModeIsNotSigned() throws {
        let operation = try relayed(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], mode: "0x01" + String(repeating: "0", count: 62))

        XCTAssertNotNil(refusal(operation, fee: .battery))
    }

    func testAnEmptyCallReadsTheSameHoweverItIsSpelled() {
        XCTAssertEqual(
            HermesExecute.Call(target: foreign.uppercased().replacingOccurrences(of: "0X", with: "0x"), value: "1", data: "0x"),
            HermesExecute.Call(target: foreign, value: "1", data: "")
        )
    }

    private func refusal(_ operation: MultichainRelayedOperation, fee: HermesExecute.Fee) -> String? {
        HermesExecute.refusal(of: operation, calls: asked, chain: .eth, owner: GaslessFixtures.sender, fee: fee, now: now)
    }

    private func relayed(
        calls: [(target: String, data: String)],
        mode: String? = nil,
        authorizationMeta: String = GaslessFixtures.authorizationMeta
    ) throws -> MultichainRelayedOperation {
        try MultichainRelayedOperation(
            id: "bcef74e1-b940-4142-b7a7-76161850971e",
            json: GaslessFixtures.operation(authorizationMeta: authorizationMeta, calls: calls, mode: mode ?? batteryMode, deadline: deadline)
        )
    }

    private func twoAuthorizations() throws -> MultichainRelayedOperation {
        let json = GaslessFixtures.operation(calls: [(GaslessFixtures.usdtContract, GaslessFixtures.usdtTransfer)], mode: batteryMode, deadline: deadline)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        var payloads = try XCTUnwrap(envelope["payloads"] as? [[String: Any]])
        var second = payloads[0]
        second["id"] = "p_auth_2"
        payloads.insert(second, at: 1)
        envelope["payloads"] = payloads
        let data = try JSONSerialization.data(withJSONObject: envelope)
        return try MultichainRelayedOperation(id: "bcef74e1-b940-4142-b7a7-76161850971e", json: String(decoding: data, as: UTF8.self))
    }

    private func transfer(_ amount: BigUInt) -> String {
        let hex = String(amount, radix: 16)
        return "0x" + PerpsDepositCalldata.transferSelector
            + String(repeating: "0", count: 24) + feeRecipient.dropFirst(2)
            + String(repeating: "0", count: 64 - hex.count) + hex
    }
}
