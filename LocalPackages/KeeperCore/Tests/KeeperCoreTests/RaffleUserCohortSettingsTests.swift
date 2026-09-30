import Foundation
import TKFeatureFlags
import XCTest

final class RaffleUserCohortSettingsTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RaffleUserCohortSettingsTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_cohortStartsUnresolved() {
        XCTAssertNil(UserDefaultsTKAppSettings(userDefaults: userDefaults).raffleIsNewUser)
    }

    func test_cohortRoundTripsBothValues() {
        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)

        settings.raffleIsNewUser = true
        XCTAssertEqual(settings.raffleIsNewUser, true)

        settings.raffleIsNewUser = false
        XCTAssertEqual(settings.raffleIsNewUser, false)
    }

    func test_cohortPersistsAcrossSettingsInstances() {
        UserDefaultsTKAppSettings(userDefaults: userDefaults).raffleIsNewUser = false

        XCTAssertEqual(UserDefaultsTKAppSettings(userDefaults: userDefaults).raffleIsNewUser, false)
    }

    func test_assigningNilClearsCohort() {
        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)
        settings.raffleIsNewUser = true

        settings.raffleIsNewUser = nil

        XCTAssertNil(settings.raffleIsNewUser)
    }

    func test_legacyTapBasedValueDoesNotPreResolveCohort() {
        userDefaults.set(true, forKey: "raffleIsNewUser")

        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)

        XCTAssertNil(settings.raffleIsNewUser)
    }
}
