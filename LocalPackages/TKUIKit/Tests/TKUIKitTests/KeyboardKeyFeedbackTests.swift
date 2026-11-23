@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class KeyboardKeyFeedbackTests: XCTestCase {
    func testReleasePlaysOnlyAfterALongTapThatStayedOnTheKey() {
        var time: TimeInterval = 0
        let rigid = ImpactSpy()
        let soft = ImpactSpy()
        let feedback = KeyboardKeyFeedback(rigid: rigid, soft: soft, now: { time })
        let first = NSObject()
        let second = NSObject()
        let key = ObjectIdentifier(first)
        let otherKey = ObjectIdentifier(second)

        feedback.press(key)
        time = 0.3
        feedback.release(key)

        feedback.press(key)
        time = 0.8
        feedback.release(key)

        feedback.press(key)
        time = 2
        feedback.cancel(key)
        feedback.release(key)

        feedback.press(key)
        time = 2.1
        feedback.press(otherKey)
        time = 2.2
        feedback.release(otherKey)
        time = 2.5
        feedback.release(key)

        XCTAssertEqual(rigid.intensities, [0.7, 0.7, 0.7, 0.7, 0.7])
        XCTAssertEqual(soft.intensities, [0.7, 0.7])
    }
}

private final class ImpactSpy: UIImpactFeedbackGenerator {
    private(set) var intensities: [CGFloat] = []

    override init() {
        super.init(style: .light)
    }

    override func impactOccurred(intensity: CGFloat) {
        intensities.append(intensity)
    }
}
