@testable import Perps
import XCTest

final class PerpsFormattingTests: XCTestCase {
    func test_usd_keepsTheCentsADoubleCarries() {
        XCTAssertEqual(PerpsFormatting.test.usd(0.47), "$0.47")
        XCTAssertEqual(PerpsFormatting.test.usd(1.18), "$1.18")
    }
}
