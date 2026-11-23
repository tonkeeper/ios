@testable import TKUIKit
import XCTest

final class TKTickerViewTests: XCTestCase {
    func testTickerMovesOneCopyPerLoop() throws {
        let animation = try XCTUnwrap(TKTickerView.tickerAnimation(textWidth: 200, pointsPerSecond: 25))

        XCTAssertEqual(animation.keyPath, "transform.translation.x")
        XCTAssertEqual(try XCTUnwrap(animation.fromValue as? CGFloat), -200)
        XCTAssertEqual(try XCTUnwrap(animation.toValue as? CGFloat), 0)
        XCTAssertEqual(animation.duration, 8, accuracy: 0.0001)
        XCTAssertEqual(animation.repeatCount, .infinity)
    }

    func testTickerWithoutWidthDoesNotMove() {
        XCTAssertNil(TKTickerView.tickerAnimation(textWidth: 0, pointsPerSecond: 25))
        XCTAssertNil(TKTickerView.tickerAnimation(textWidth: 200, pointsPerSecond: 0))
    }
}
