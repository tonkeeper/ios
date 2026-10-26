@testable import KeeperCore
import XCTest

final class WalletConnectRequestFactoryTests: XCTestCase {
    func testBuildsSendTransactionRequest() throws {
        let transaction = WalletConnectEVMTransaction(
            from: "0xfrom",
            to: "0xto",
            data: "0x",
            value: "0x0",
            nonce: nil,
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )

        let request = try makeRequest(method: .ethSendTransaction, payload: .evmTransaction(transaction, send: true))

        XCTAssertEqual(request.method, .ethSendTransaction)
        XCTAssertEqual(request.chain, .base)
        XCTAssertEqual(request.payload, .evmTransaction(transaction, send: true))
        XCTAssertEqual(request.walletId, "wallet")
    }

    func testRejectsMethodsOutsideTheChainNamespace() {
        XCTAssertThrowsError(
            try makeRequest(method: .tonSendMessage, payload: .signMessage(message("0x68656c6c6f", kind: .personal)))
        ) { error in
            XCTAssertEqual(error as? WalletConnectRequestParsingError, .unsupportedMethod("ton_sendMessage"))
        }
    }

    func testRejectsTypedDataWhoseDomainNamesAnotherChain() {
        let typedData = #"{"domain":{"chainId":137},"message":{}}"#

        XCTAssertThrowsError(
            try makeRequest(method: .ethSignTypedDataV4, payload: .signMessage(message(typedData, kind: .typedDataV4)))
        ) { error in
            XCTAssertEqual(error as? WalletConnectRequestParsingError, .chainMismatch(expected: .base, actual: "137"))
        }
    }

    func testAcceptsTypedDataWithoutADomainChain() throws {
        let typedData = #"{"domain":{"name":"Vaults"},"message":{}}"#

        let request = try makeRequest(method: .ethSignTypedDataV4, payload: .signMessage(message(typedData, kind: .typedDataV4)))

        XCTAssertEqual(request.method, .ethSignTypedDataV4)
    }
}

private extension WalletConnectRequestFactoryTests {
    var dapp: WalletConnectDapp {
        WalletConnectDapp(name: "Earn", url: "https://vaults.fyi", description: "", iconURL: nil)
    }

    func message(_ message: String, kind: WalletConnectSignMessageKind) -> WalletConnectSignMessage {
        WalletConnectSignMessage(address: "0xaddress", message: message, kind: kind)
    }

    func makeRequest(method: WalletConnectMethod, payload: WalletConnectRequestPayload) throws -> WalletConnectSessionRequest {
        try WalletConnectRequestFactory.makeRequest(
            id: "1",
            topic: "earn",
            method: method,
            chain: .base,
            payload: payload,
            dapp: dapp,
            source: nil,
            walletId: "wallet"
        )
    }
}
