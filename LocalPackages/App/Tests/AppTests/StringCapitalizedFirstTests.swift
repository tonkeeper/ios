@testable import App
import XCTest

final class StringCapitalizedFirstTests: XCTestCase {
    func testHistorySectionTitlesPreserveMonthCase() {
        XCTAssertEqual("15 октября".capitalizedFirst, "15 октября")
        XCTAssertEqual("октябрь".capitalizedFirst, "Октябрь")
        XCTAssertEqual("октябрь 2025".capitalizedFirst, "Октябрь 2025")
        XCTAssertEqual("15 October".capitalizedFirst, "15 October")
        XCTAssertEqual("".capitalizedFirst, "")
    }
}
