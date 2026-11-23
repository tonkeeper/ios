@testable import TKUIKit
import XCTest

@MainActor
final class TKConfirmSliderTests: XCTestCase {
    func testArmsAt88PercentAndDisarmsOnlyBelow85() {
        XCTAssertFalse(TKConfirmSlider.isArmed(wasArmed: false, progress: 0.87))
        XCTAssertTrue(TKConfirmSlider.isArmed(wasArmed: false, progress: 0.88))
        XCTAssertTrue(TKConfirmSlider.isArmed(wasArmed: true, progress: 0.85))
        XCTAssertFalse(TKConfirmSlider.isArmed(wasArmed: true, progress: 0.84))
    }

    func testCommitsWhenArmedOrFlungFastPast60Percent() {
        XCTAssertTrue(TKConfirmSlider.shouldCommit(isArmed: true, progress: 0.86, velocity: 0))
        XCTAssertTrue(TKConfirmSlider.shouldCommit(isArmed: false, progress: 0.61, velocity: 1401))
        XCTAssertFalse(TKConfirmSlider.shouldCommit(isArmed: false, progress: 0.6, velocity: 3000))
        XCTAssertFalse(TKConfirmSlider.shouldCommit(isArmed: false, progress: 0.8, velocity: 1400))
    }

    func testTicksEverySixPoints() {
        XCTAssertEqual(TKConfirmSlider.tickStep(pull: 5.9), 0)
        XCTAssertEqual(TKConfirmSlider.tickStep(pull: 6), 1)
        XCTAssertEqual(TKConfirmSlider.tickStep(pull: 13), 2)
    }

    func testLabelDimsOnPressAndIsGoneBy60Percent() {
        XCTAssertEqual(TKConfirmSlider.labelStyle(isPressed: false, progress: 0), .init(opacity: 1, offset: 0, blur: 0))
        XCTAssertEqual(TKConfirmSlider.labelStyle(isPressed: true, progress: 0), .init(opacity: 0.55, offset: 0, blur: 0))
        XCTAssertEqual(TKConfirmSlider.labelStyle(isPressed: true, progress: 0.6), .init(opacity: 0, offset: 22, blur: 3))
        XCTAssertEqual(TKConfirmSlider.labelStyle(isPressed: true, progress: 1), .init(opacity: 0, offset: 22, blur: 3))
    }

    func testReturnTicksCrossEachStepOnTheWayBackInTimeOrder() {
        let ticks = TKConfirmSlider.returnTicks(from: 30, maxPull: 294)
        XCTAssertEqual(ticks.map(\.progress), ([24, 18, 12, 6] as [CGFloat]).map { $0 / 294 })
        XCTAssertEqual(ticks.map(\.time), ticks.map(\.time).sorted())
        XCTAssertGreaterThan(ticks.first?.time ?? 0, 0)
        XCTAssertLessThan(ticks.last?.time ?? 1, 0.46)
    }

    func testLandingPlaysAfterTheLastTickAndScalesWithThePull() throws {
        XCTAssertNil(TKConfirmSlider.landingTime(from: 0))
        let short = try XCTUnwrap(TKConfirmSlider.landingTime(from: 6))
        let long = try XCTUnwrap(TKConfirmSlider.landingTime(from: 300))
        XCTAssertLessThan(short, long)
        XCTAssertLessThan(long, 0.46)
        let lastTick = try XCTUnwrap(TKConfirmSlider.returnTicks(from: 300, maxPull: 306).last)
        XCTAssertGreaterThan(long, lastTick.time)
    }

    func testNoReturnTicksWithinTheFirstStep() {
        XCTAssertTrue(TKConfirmSlider.returnTicks(from: 6, maxPull: 294).isEmpty)
        XCTAssertTrue(TKConfirmSlider.returnTicks(from: 0, maxPull: 294).isEmpty)
    }
}
