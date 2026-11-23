@testable import KeeperCore
import TonSwift
import XCTest

final class TransferErrorBroadcastFailureTests: XCTestCase {
    func test_batteryRefusal_readsItsStatusAndCode() throws {
        let refusal = BatteryAPI.ApiError.rejected(status: 400, code: "not_enough_charges", message: "Not enough charges")

        let failure = try TransferError.broadcastFailure(
            refusal,
            count: 1,
            transferType: .battery(excessAddress: Address.parse(Self.excessAddress))
        )

        guard case let .sendFailed(message, relayerRefusal) = failure else {
            return XCTFail("expected sendFailed, got \(failure)")
        }
        let text = try XCTUnwrap(message)
        XCTAssertEqual(text, "failed to single battery send due to error: \(refusal.logDescription)")
        XCTAssertTrue(text.contains("status=400"), text)
        XCTAssertTrue(text.contains("code=not_enough_charges"), text)
        XCTAssertEqual(relayerRefusal, RelayerRefusal(status: 400, code: "not_enough_charges"))
        XCTAssertEqual(relayerRefusal?.isFundsShortage, false)
    }

    func test_batteryRefusalForLackOfFunds_isKeptAsAShortage() throws {
        let refusal = BatteryAPI.messageRejection(
            status: 402,
            message: "Not enough balance to send message",
            key: "err-gasless-balance"
        )

        let failure = try TransferError.broadcastFailure(
            refusal,
            count: 1,
            transferType: .battery(excessAddress: Address.parse(Self.excessAddress))
        )

        guard case let .sendFailed(message, relayerRefusal) = failure else {
            return XCTFail("expected sendFailed, got \(failure)")
        }
        XCTAssertTrue(try XCTUnwrap(message).contains("code=err-gasless-balance"))
        XCTAssertEqual(relayerRefusal?.isFundsShortage, true)
    }

    func test_tonAPIRefusal_readsAsTheBatteryOneDoes() throws {
        let body = try JSONSerialization.data(withJSONObject: ["error": "duplicate message"])

        let failure = TransferError.broadcastFailure(
            TonAPIError(statusCode: 406, body: body, path: nil),
            count: 2,
            transferType: .default
        )

        guard case let .sendFailed(message, refusal) = failure else {
            return XCTFail("expected sendFailed, got \(failure)")
        }
        XCTAssertEqual(message, "failed to batch default send due to error: 406 duplicate message")
        XCTAssertNil(refusal)
    }
}

private extension TransferErrorBroadcastFailureTests {
    static let excessAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"
}
