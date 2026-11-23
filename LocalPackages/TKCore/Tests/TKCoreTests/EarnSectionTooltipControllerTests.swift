import Foundation
@testable import TKServices
import XCTest

@MainActor
final class EarnSectionTooltipControllerTests: XCTestCase {
    private static let suiteName = "EarnSectionTooltipControllerTests"

    private var userDefaults: UserDefaults!
    private var repository: EarnSectionTooltipRepository!
    private var controller: EarnSectionTooltipController!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: Self.suiteName)
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        repository = EarnSectionTooltipRepository(userDefaults: userDefaults)
        controller = EarnSectionTooltipController(repository: repository)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        controller = nil
        repository = nil
        userDefaults = nil
        super.tearDown()
    }

    func testShowsAtMostOnceADay() {
        XCTAssertTrue(controller.canShowTooltip)

        controller.didShowTooltip()

        XCTAssertFalse(controller.canShowTooltip)
    }

    func testShowsOnLaterDaysUntilShownThreeTimes() {
        for _ in 0 ..< 3 {
            XCTAssertTrue(controller.canShowTooltip)
            controller.didShowTooltip()
            repository.lastShownDate = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
        }

        XCTAssertFalse(controller.canShowTooltip)
    }
}
