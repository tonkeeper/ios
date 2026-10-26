import ChainKit
@testable import KeeperCore
import XCTest

final class MultichainRelayedOperationTests: XCTestCase {
    private let id = "bcef74e1-b940-4142-b7a7-76161850971e"

    func test_theRelayersDocumentsAreReadInOrder() throws {
        let operation = try MultichainRelayedOperation(id: id, json: GaslessFixtures.operation())

        XCTAssertEqual(operation.id, id)
        XCTAssertEqual(operation.payloadIds, ["p_auth", "p_user"])
        XCTAssertEqual(
            operation.operation.payloads.map(\.type),
            [ChainKit.Payload.Type_.eip7702authorization, ChainKit.Payload.Type_.eip7821hermesdelegate]
        )
    }

    /// Only what a relayer submits is signed here: a `main` payload would come back as a
    /// transaction the wallet pays for.
    func test_anOperationWithATransactionOfTheWalletsOwnIsRefused() {
        let json = GaslessFixtures.operation(
            authorizationPayloadType: "main",
            authorizationMeta: #"{ "to": "\#(GaslessFixtures.usdtContract)", "value": "0", "data": "\#(GaslessFixtures.usdtTransfer)" }"#
        )

        XCTAssertThrowsError(try MultichainRelayedOperation(id: id, json: json)) { error in
            XCTAssertEqual(
                error as? MultichainRelayedOperationError,
                .foreignPayload(id: "p_auth", type: "main")
            )
        }
    }

    func test_anEnvelopeChainKitCannotReadIsMalformed() {
        XCTAssertThrowsError(try MultichainRelayedOperation(id: id, json: "not json")) { error in
            guard case .malformed = error as? MultichainRelayedOperationError else {
                return XCTFail("expected a malformed operation, got \(error)")
            }
        }
    }
}
