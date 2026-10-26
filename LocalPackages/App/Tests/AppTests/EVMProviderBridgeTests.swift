@testable import App
import KeeperCore
import XCTest

final class EVMProviderBridgeTests: XCTestCase {
    func test_requestsDecodeIntoTheMethodsTheProviderSupports() {
        XCTAssertEqual(EVMProviderRequest(args: [["method": "eth_accounts"]]), .accounts)
        XCTAssertEqual(EVMProviderRequest(args: [["method": "eth_requestAccounts", "params": []]]), .accounts)
        XCTAssertEqual(EVMProviderRequest(args: [["method": "eth_chainId"]]), .chainId)
        XCTAssertEqual(EVMProviderRequest(args: [["method": "net_version"]]), .netVersion)
        XCTAssertEqual(
            EVMProviderRequest(args: [["method": "wallet_switchEthereumChain", "params": [["chainId": "0x2105"]]]]),
            .switchChain(chainId: "0x2105")
        )
        XCTAssertEqual(
            EVMProviderRequest(args: [["method": "personal_sign", "params": ["0x68656c6c6f", "0xaddress"]]]),
            .personalSign(message: "0x68656c6c6f", address: "0xaddress")
        )
        XCTAssertEqual(
            EVMProviderRequest(args: [["method": "eth_signTypedData_v4", "params": ["0xaddress", "{}"]]]),
            .signTypedDataV4(address: "0xaddress", typedData: "{}")
        )
        XCTAssertEqual(EVMProviderRequest(args: [["method": "eth_call", "params": []]]), .unsupported(method: "eth_call"))
    }

    func test_transactionRequestDecodesTheTransaction() throws {
        let request = try XCTUnwrap(
            EVMProviderRequest(args: [[
                "method": "eth_sendTransaction",
                "params": [["from": "0xfrom", "to": "0xto", "data": "0x", "value": "0x0"]],
            ]])
        )

        guard case let .sendTransaction(transaction) = request else {
            return XCTFail("expected a transaction, got \(request)")
        }
        XCTAssertEqual(transaction.from, "0xfrom")
        XCTAssertEqual(transaction.to, "0xto")
        XCTAssertEqual(transaction.value, "0x0")
    }

    func test_malformedRequestsAreRejected() {
        XCTAssertNil(EVMProviderRequest(args: []))
        XCTAssertNil(EVMProviderRequest(args: ["eth_accounts"]))
        XCTAssertNil(EVMProviderRequest(args: [["params": []]]))
        XCTAssertNil(EVMProviderRequest(args: [["method": ""]]))
        XCTAssertNil(EVMProviderRequest(args: [["method": "personal_sign", "params": ["0x68656c6c6f"]]]))
        XCTAssertNil(EVMProviderRequest(args: [["method": "wallet_switchEthereumChain", "params": []]]))
        XCTAssertNil(EVMProviderRequest(args: [["method": "eth_sendTransaction"]]))
    }

    func test_chainIdIsHexEncodedTheWayTheProviderReportsIt() {
        XCTAssertEqual(EVMProviderBridge.chainIdHex(1), "0x1")
        XCTAssertEqual(EVMProviderBridge.chainIdHex(8453), "0x2105")
        XCTAssertEqual(EVMProviderBridge.chainIdHex(42161), "0xa4b1")
        XCTAssertEqual(EVMProviderBridge.chainIdHex(56), "0x38")
    }

    func test_responsesAreJsonFragments() {
        XCTAssertEqual(EVMProviderBridge.responseJson("0x1"), "\"0x1\"")
        XCTAssertEqual(EVMProviderBridge.responseJson(["0xabc"]), "[\"0xabc\"]")
        XCTAssertEqual(EVMProviderBridge.responseJson(EVMProviderBridge.Null()), "null")
    }

    func test_eventsRideTheNativeEventEnvelope() throws {
        let accounts = try decode(XCTUnwrap(EVMProviderEvent.accountsChanged(["0xabc"]).json))
        XCTAssertEqual(accounts["type"] as? String, "nativeEvent")
        XCTAssertEqual(accounts["event"] as? String, "ethereum.accountsChanged")
        XCTAssertEqual(accounts["payload"] as? [String], ["0xabc"])

        let chain = try decode(XCTUnwrap(EVMProviderEvent.chainChanged(chainIdHex: "0x2105").json))
        XCTAssertEqual(chain["event"] as? String, "ethereum.chainChanged")
        XCTAssertEqual(chain["payload"] as? String, "0x2105")
    }

    func test_injectionExposesTheProviderContract() {
        let injection = EVMProviderBridge.injection(address: "0xabc", chainIdHex: "0x1")

        XCTAssertTrue(injection.contains("window.ethereum = {"))
        XCTAssertTrue(injection.contains("request: ({ method, params }) =>"))
        XCTAssertTrue(injection.contains("on: (event, handler) =>"))
        XCTAssertTrue(injection.contains("removeListener: (event, handler) =>"))
        XCTAssertTrue(injection.contains("selectedAddress: '0xabc'"))
        XCTAssertTrue(injection.contains("chainId: '0x1'"))
        XCTAssertTrue(injection.contains("'eth.request'"))
    }
}

private extension EVMProviderBridgeTests {
    func decode(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))) as? [String: Any])
    }
}
