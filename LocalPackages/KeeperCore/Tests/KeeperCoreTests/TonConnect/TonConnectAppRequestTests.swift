@testable import KeeperCore
import TonSwift
import XCTest

final class TonConnectAppRequestTests: XCTestCase {
    func testDecodesDisconnectRequest() throws {
        let request = try decode(#"{"method":"disconnect","params":[],"id":"1"}"#)

        guard case let .disconnect(disconnect) = request else {
            return XCTFail("Expected disconnect, got \(request)")
        }
        XCTAssertEqual(disconnect.id, "1")
    }

    func testDecodeSignDataWithoutParamsThrowsInsteadOfTrapping() {
        XCTAssertThrowsError(try decode(#"{"method":"signData","params":[],"id":"1"}"#)) { error in
            guard case AppRequestError.noParams = error else {
                return XCTFail("Expected noParams, got \(error)")
            }
        }
    }

    func testDecodeUnknownMethodThrowsWithMethodName() {
        XCTAssertThrowsError(try decode(#"{"method":"signTransaction","params":[],"id":"1"}"#)) { error in
            guard case let AppRequestError.unknownMethod(method) = error else {
                return XCTFail("Expected unknownMethod, got \(error)")
            }
            XCTAssertEqual(method, "signTransaction")
        }
    }

    func testDecodesSignMessageRequest() throws {
        let request = try decode(
            #"{"method":"signMessage","params":["{\"valid_until\":1764424242,\"network\":\"-239\",\"from\":\"Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU\",\"messages\":[{\"address\":\"Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU\",\"amount\":\"100000000\"}]}"],"id":"43"}"#
        )

        guard case let .signMessage(signMessage) = request else {
            return XCTFail("Expected signMessage, got \(request)")
        }
        XCTAssertEqual(signMessage.id, "43")
        XCTAssertEqual(signMessage.params.validUntil, 1_764_424_242)
        XCTAssertEqual(signMessage.params.network, "-239")
        XCTAssertEqual(signMessage.params.from, try Address.parse("Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU"))
        XCTAssertEqual(signMessage.params.messages.map(\.amount), [100_000_000])
    }

    func testDecodeSignMessageWithoutParamsThrows() {
        XCTAssertThrowsError(try decode(#"{"method":"signMessage","params":[],"id":"1"}"#)) { error in
            guard case AppRequestError.noParams = error else {
                return XCTFail("Expected noParams, got \(error)")
            }
        }
    }

    func testDecodeSignMessageWithItemsOnlyThrows() {
        XCTAssertThrowsError(
            try decode(
                #"{"method":"signMessage","params":["{\"items\":[{\"type\":\"ton\",\"address\":\"Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU\",\"amount\":\"1\"}]}"],"id":"1"}"#
            )
        )
    }

    func testDecodesNumericNetwork() throws {
        let request = try decode(
            #"{"method":"signMessage","params":["{\"network\":-3,\"messages\":[{\"address\":\"Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU\",\"amount\":\"1\"}]}"],"id":"1"}"#
        )

        guard case let .signMessage(signMessage) = request else {
            return XCTFail("Expected signMessage, got \(request)")
        }
        XCTAssertEqual(signMessage.params.network, "-3")
    }

    func testDecodesSendTransactionWithoutSender() throws {
        let request = try decode(
            #"{"method":"sendTransaction","params":["{\"messages\":[{\"address\":\"Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU\",\"amount\":\"1\"}]}"],"id":"1"}"#
        )

        guard case let .sendTransaction(sendTransaction) = request else {
            return XCTFail("Expected sendTransaction, got \(request)")
        }
        XCTAssertEqual(sendTransaction.params.count, 1)
        XCTAssertNil(sendTransaction.params.first?.from)
    }

    func testSignMessageResponseEncodesInternalBocObject() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(
            TonConnect.SendResponse.success(.init(result: TonConnect.SignMessageResult(internalBoc: "te6cc"), id: "43"))
        )

        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"id":"43","result":{"internalBoc":"te6cc"}}"#)
    }

    func testDisconnectResponseEncodesEmptyResultObject() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(TonConnect.SendResponse.success(.init(id: "1")))

        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"id":"1","result":{}}"#)
    }

    private func decode(_ json: String) throws -> TonConnect.AppRequest {
        try JSONDecoder().decode(TonConnect.AppRequest.self, from: Data(json.utf8))
    }
}
