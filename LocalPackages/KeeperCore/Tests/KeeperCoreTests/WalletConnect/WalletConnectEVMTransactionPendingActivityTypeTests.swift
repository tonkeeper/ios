@testable import KeeperCore
import XCTest

final class WalletConnectEVMTransactionPendingActivityTypeTests: XCTestCase {
    private let transferSelector = "a9059cbb"
    private let approveSelector = "095ea7b3"
    private let transferFromSelector = "23b872dd"

    func testEmptyCalldataIsReportedAsSend() {
        for data in ["0x", "", " 0x "] {
            XCTAssertEqual(transaction(data: data).pendingActivityType, .send, data)
        }
    }

    func testERC20TransferIsReportedAsSend() {
        XCTAssertEqual(transaction(data: erc20Calldata(selector: transferSelector)).pendingActivityType, .send)
        XCTAssertEqual(transaction(data: erc20Calldata(selector: transferSelector.uppercased())).pendingActivityType, .send)
    }

    func testOtherCalldataIsReportedAsContractCall() {
        let transfer = erc20Calldata(selector: transferSelector)

        for data in [
            erc20Calldata(selector: approveSelector),
            "0x" + transferFromSelector + String(repeating: "0", count: 192),
            String(transfer.dropLast(2)),
            transfer + "00",
            "0x00",
            "0xzz",
        ] {
            XCTAssertEqual(transaction(data: data).pendingActivityType, .contractCall, data)
        }
    }
}

private extension WalletConnectEVMTransactionPendingActivityTypeTests {
    func erc20Calldata(selector: String) -> String {
        let recipient = String(repeating: "0", count: 24) + "9858effd232b4033e47d90003d41ec34ecaeda94"
        let amount = String(repeating: "0", count: 58) + "0f4240"
        return "0x" + selector + recipient + amount
    }

    func transaction(data: String) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: nil,
            to: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            data: data,
            value: "0x0",
            nonce: nil,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }
}
