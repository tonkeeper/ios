@testable import KeeperCore
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
        XCTAssertThrowsError(try decode(#"{"method":"signMessage","params":[],"id":"1"}"#)) { error in
            guard case let AppRequestError.unknownMethod(method) = error else {
                return XCTFail("Expected unknownMethod, got \(error)")
            }
            XCTAssertEqual(method, "signMessage")
        }
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
