@testable import KeeperCore
import XCTest

final class PerpsMarketMathTests: XCTestCase {
    func test_optionalDouble_rejectsNonFiniteAndGarbageStrings() {
        for raw in ["nan", "NaN", "inf", "Infinity", "1e400", "-1e400", "abc", ""] {
            XCTAssertNil(PerpsMarketMath.optionalDouble(raw), raw)
        }
        XCTAssertEqual(PerpsMarketMath.optionalDouble("1.5"), 1.5)
        XCTAssertEqual(PerpsMarketMath.optionalDouble("-0.01"), -0.01)
    }

    func test_optionalDouble_keepsHugeDecimalsFinite() {
        let value = PerpsMarketMath.optionalDouble("79228162514264337593543950336e100")
        XCTAssertEqual(value?.isFinite, true)
    }

    func test_changePercent_recomputesLiveAgainstSnapshotBaseline() {
        XCTAssertEqual(
            PerpsMarketMath.changePercent(livePrice: 110, snapshotPrice: 100, snapshotChangePercent: 25),
            37.5,
            accuracy: 1e-9
        )
    }

    func test_changePercent_fallsBackToSnapshotPercentOnDegenerateInputs() {
        XCTAssertEqual(
            PerpsMarketMath.changePercent(livePrice: 110, snapshotPrice: 100, snapshotChangePercent: -100),
            -100
        )
        XCTAssertEqual(
            PerpsMarketMath.changePercent(livePrice: 110, snapshotPrice: 0, snapshotChangePercent: 5),
            5
        )
        XCTAssertEqual(
            PerpsMarketMath.changePercent(livePrice: 0, snapshotPrice: 100, snapshotChangePercent: 5),
            5
        )
    }

    func test_changeAmount_isZeroWhenPercentFactorDegenerates() {
        XCTAssertEqual(PerpsMarketMath.changeAmount(price: 100, changePercent: -100), 0)
        XCTAssertEqual(PerpsMarketMath.changeAmount(price: 100, changePercent: 25), 20, accuracy: 1e-9)
    }
}
