@testable import App
import KeeperCore
import XCTest

final class WalletConnectRequestDetailsTests: XCTestCase {
    func testRawDataShowsOnlyTheTransactionFieldsTheWalletSigns() {
        let request = request(
            transaction: WalletConnectEVMTransaction(
                from: "0x9858effd232b4033e47d90003d41ec34ecaeda94",
                to: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                data: "0x",
                value: "0x1",
                nonce: "0x5",
                gas: "0x5208",
                gasPrice: "0x3b9aca00",
                maxFeePerGas: "0x77359400",
                maxPriorityFeePerGas: "0x3b9aca00"
            )
        )

        let ids = WalletConnectRequestAssembly.detailItems(for: request).flatMap(\.ids)

        XCTAssertEqual(
            Set(ids),
            ["rawData", "rawData.from", "rawData.to", "rawData.value", "rawData.data", "rawData.nonce"]
        )
    }
}

private extension WalletConnectRequestDetailsTests {
    func request(transaction: WalletConnectEVMTransaction) -> WalletConnectSessionRequest {
        WalletConnectSessionRequest(
            id: "1",
            topic: "topic",
            chain: .eth,
            method: .ethSendTransaction,
            dapp: WalletConnectDapp(
                name: "dApp",
                url: "https://example.com",
                description: "",
                iconURL: nil
            ),
            payload: .evmTransaction(transaction, send: true),
            source: .deeplink,
            walletId: "wallet"
        )
    }
}

private extension WalletConnectRequestDetailItem {
    var ids: [String] {
        switch value {
        case .primitive:
            [id]
        case let .collection(children):
            [id] + children.flatMap(\.ids)
        }
    }
}
