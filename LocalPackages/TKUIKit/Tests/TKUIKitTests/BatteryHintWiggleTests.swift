@testable import TKUIKit
import XCTest

final class BatteryHintWiggleTests: XCTestCase {
    func test_restsAtBothEnds() {
        XCTAssertEqual(BatteryHintWiggle.frame(at: 0), .init(angle: 0, scale: 1))
        XCTAssertEqual(BatteryHintWiggle.frame(at: 1), .init(angle: 0, scale: 1))
    }

    func test_hitsTheDesignKeyframes() {
        XCTAssertEqual(frame(atSeconds: 0.08).angle, 12, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.18).angle, -10, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.28).angle, 8, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.38).angle, -6, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.48).angle, 3, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.6).angle, 0, accuracy: 0.001)
        XCTAssertEqual(frame(atSeconds: 0.12).scale, 1.12, accuracy: 0.001)
    }

    func test_staysWithinTheKeyframeRange() {
        for step in 0 ... 100 {
            let frame = BatteryHintWiggle.frame(at: CGFloat(step) / 100)
            XCTAssertTrue((-10.001 ... 12.001).contains(frame.angle), "\(step): \(frame.angle)")
            XCTAssertTrue((0.999 ... 1.121).contains(frame.scale), "\(step): \(frame.scale)")
        }
    }

    private func frame(atSeconds seconds: CGFloat) -> BatteryHintWiggle.Frame {
        BatteryHintWiggle.frame(at: seconds / CGFloat(BatteryHintWiggle.duration))
    }
}
