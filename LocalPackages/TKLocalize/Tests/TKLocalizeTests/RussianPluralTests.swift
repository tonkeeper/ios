import XCTest
@testable import TKLocalize

final class RussianPluralTests: XCTestCase {
  func test() {
    XCTAssertTrue(russianPlural(count: 0) == .zero)
    XCTAssertTrue(russianPlural(count: 1) == .one)
    XCTAssertTrue(russianPlural(count: 2) == .few)
    XCTAssertTrue(russianPlural(count: 4) == .few)
    XCTAssertTrue(russianPlural(count: 5) == .many)
    XCTAssertTrue(russianPlural(count: 10) == .many)
    XCTAssertTrue(russianPlural(count: 11) == .many)
    XCTAssertTrue(russianPlural(count: 21) == .one)
  }
}
