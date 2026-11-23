@testable import TKUIKit
import UIKit
import XCTest

final class CircularLoaderAnimationTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testCountdownContinuesFromWhereItStands() throws {
        let animation = try XCTUnwrap(countdown(duration: 12, startedSecondsAgo: 3))

        XCTAssertEqual(try XCTUnwrap(animation.fromValue as? Double), 0.25, accuracy: 0.0001)
        XCTAssertEqual(animation.toValue as? Double, 1)
        XCTAssertEqual(animation.duration, 9, accuracy: 0.0001)
        XCTAssertEqual(animation.beginTime, 0)
    }

    func testCountdownThatStartsLaterWaitsEmpty() throws {
        let animation = try XCTUnwrap(countdown(duration: 12, startedSecondsAgo: -2, mediaTime: 500))

        XCTAssertEqual(animation.fromValue as? Double, 0)
        XCTAssertEqual(animation.duration, 12, accuracy: 0.0001)
        XCTAssertEqual(animation.beginTime, 502, accuracy: 0.0001)
        XCTAssertEqual(animation.fillMode, .backwards)
    }

    func testCountdownThatRanOutHasNoAnimation() {
        XCTAssertNil(countdown(duration: 12, startedSecondsAgo: 12))
        XCTAssertNil(countdown(duration: 0, startedSecondsAgo: 0))
    }

    func testSpinnersShareOneTurn() throws {
        let turn = spinner.turnDuration
        let halfTurnIn = Date(timeIntervalSinceReferenceDate: turn * 1000 + turn / 2)

        let animation = CircularLoaderLayerView.spinnerAnimation(at: halfTurnIn, turnDuration: turn)

        XCTAssertEqual(try XCTUnwrap(animation.fromValue as? Double), .pi, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(animation.toValue as? Double), 3 * .pi, accuracy: 0.0001)
        XCTAssertEqual(animation.repeatCount, .infinity)
    }

    func testAnimationsAreOnTheLayersOnlyInAWindow() {
        let view = CircularLoaderLayerView()
        view.update(timing: spinnerTiming, spinner: spinner, lineWidth: 2, progressColor: .white, trackColor: .gray)
        XCTAssertNil(view.progressAnimation)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(view)
        XCTAssertNotNil(view.progressAnimation)

        view.removeFromSuperview()
        XCTAssertNil(view.progressAnimation)
    }

    func testStoppedViewStaysStoppedThroughWindowAndForeground() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = CircularLoaderLayerView()
        view.update(timing: spinnerTiming, spinner: spinner, lineWidth: 2, progressColor: .white, trackColor: .gray)
        window.addSubview(view)

        view.stopAnimation()
        view.removeFromSuperview()
        window.addSubview(view)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertNil(view.progressAnimation)
    }

    func testForegroundPutsBackWhatTheSystemDropped() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = CircularLoaderLayerView()
        view.update(timing: spinnerTiming, spinner: spinner, lineWidth: 2, progressColor: .white, trackColor: .gray)
        window.addSubview(view)

        view.progressLayer.removeAllAnimations()
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertNotNil(view.progressAnimation)
    }

    func testUnchangedTimingKeepsTheRunningAnimation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = CircularLoaderLayerView()
        let timing = CircularLoaderLayerView.Timing(mode: .determinate, duration: 12, startDate: Date())
        view.update(timing: timing, spinner: spinner, lineWidth: 2, progressColor: .white, trackColor: .gray)
        window.addSubview(view)
        let running = try XCTUnwrap(view.progressAnimation)

        view.update(timing: timing, spinner: spinner, lineWidth: 3, progressColor: .red, trackColor: .gray)

        XCTAssertTrue(view.progressAnimation === running)
    }

    func testNewSpinnerShapeRestartsTheSpinner() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = CircularLoaderLayerView()
        view.update(timing: spinnerTiming, spinner: spinner, lineWidth: 2, progressColor: .white, trackColor: .gray)
        window.addSubview(view)

        let slower = CircularLoaderLayerView.Spinner(arcLength: 0.25, turnDuration: 1)
        view.update(timing: spinnerTiming, spinner: slower, lineWidth: 2, progressColor: .white, trackColor: .gray)

        XCTAssertEqual(try XCTUnwrap(view.progressAnimation).duration, 1)
        XCTAssertEqual(view.progressLayer.strokeEnd, 0.25)
    }
}

private extension CircularLoaderAnimationTests {
    var spinner: CircularLoaderLayerView.Spinner {
        CircularLoaderLayerView.Spinner(arcLength: 0.72, turnDuration: 0.9)
    }

    var spinnerTiming: CircularLoaderLayerView.Timing {
        CircularLoaderLayerView.Timing(mode: .indeterminate, duration: 0, startDate: now)
    }

    func countdown(duration: TimeInterval, startedSecondsAgo: TimeInterval, mediaTime: CFTimeInterval = 0) -> CABasicAnimation? {
        CircularLoaderLayerView.countdownAnimation(
            timing: CircularLoaderLayerView.Timing(
                mode: .determinate,
                duration: duration,
                startDate: now.addingTimeInterval(-startedSecondsAgo)
            ),
            now: now,
            mediaTime: mediaTime
        )
    }
}

private extension CircularLoaderLayerView {
    var progressAnimation: CAAnimation? {
        progressLayer.animationKeys()?.first.flatMap(progressLayer.animation(forKey:))
    }
}
