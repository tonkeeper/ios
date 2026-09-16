import Foundation
@testable import KeeperCore
import XCTest

final class PerpsTradingErrorMapperTests: XCTestCase {
    func testMapsTypedFoundationNetworkErrors() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            .timeout
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            ),
            .offline
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)),
            .serverUnavailable
        )
    }

    func testDoesNotInferErrorKindFromArbitraryMessageText() {
        let error = NSError(
            domain: "PerpsTradingErrorMapperTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "network balance slippage timeout"]
        )

        guard case .unknown = PerpsTradingErrorMapper.map(error) else {
            return XCTFail("untyped errors must stay unknown")
        }
    }
}
