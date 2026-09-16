@testable import KeeperCore
import XCTest

final class WalletConnectSessionStoreTests: XCTestCase {
    func testMissingCreatedAtDecodesAsUnknown() throws {
        let data = #"{"walletId":"wallet","source":"browser"}"#.data(using: .utf8)!

        let session = try JSONDecoder().decode(
            WalletConnectStoredSession.self,
            from: data
        )

        XCTAssertEqual(session.sourceState, .unknown)
    }
}
