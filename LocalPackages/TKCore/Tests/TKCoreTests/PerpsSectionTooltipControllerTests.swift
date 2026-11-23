import Foundation
@testable import TKServices
import XCTest

@MainActor
final class PerpsSectionTooltipControllerTests: XCTestCase {
    private static let suiteName = "PerpsSectionTooltipControllerTests"

    private var userDefaults: UserDefaults!
    private var appSettings: AppSettings!
    private var controller: PerpsSectionTooltipController!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: Self.suiteName)
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        appSettings = AppSettings(userDefaults: userDefaults)
        controller = PerpsSectionTooltipController(
            repository: PerpsSectionTooltipRepository(userDefaults: userDefaults),
            appSettings: appSettings
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: Self.suiteName)
        controller = nil
        appSettings = nil
        userDefaults = nil
        super.tearDown()
    }

    func testShowsOnce() {
        XCTAssertTrue(controller.canShowTooltip)

        controller.didShowTooltip()

        XCTAssertFalse(controller.canShowTooltip)
    }

    func testDoesNotShowOncePerpsWasOpened() {
        appSettings.isPerpsStoryAccepted = true

        XCTAssertFalse(controller.canShowTooltip)
    }
}
