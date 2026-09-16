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

    func test_cohortStartsUnresolvedAndFirstResolutionStaysSticky() {
        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)

        XCTAssertNil(settings.raffleIsNewUser)
        XCTAssertNil(settings.pendingRaffleIsNewUser)

        settings.beginRaffleUserResolution(isNewUser: true)
        XCTAssertEqual(settings.pendingRaffleIsNewUser, true)
        settings.resolveRaffleIsNewUser(true)
        settings.resolveRaffleIsNewUser(false)

        XCTAssertEqual(settings.raffleIsNewUser, true)
        XCTAssertNil(settings.pendingRaffleIsNewUser)
    }

    func test_existingUserResolutionPersistsAcrossSettingsInstances() {
        UserDefaultsTKAppSettings(userDefaults: userDefaults).resolveRaffleIsNewUser(false)

        let reloadedSettings = UserDefaultsTKAppSettings(userDefaults: userDefaults)
        reloadedSettings.resolveRaffleIsNewUser(true)

        XCTAssertEqual(reloadedSettings.raffleIsNewUser, false)
    }

    func test_legacyTapBasedValueDoesNotPreResolveCohort() {
        userDefaults.set(true, forKey: "raffleIsNewUser")

        let settings = UserDefaultsTKAppSettings(userDefaults: userDefaults)

        XCTAssertNil(settings.raffleIsNewUser)
    }

    func test_pendingResolutionSurvivesRestartAndCanBeCancelled() {
        UserDefaultsTKAppSettings(userDefaults: userDefaults).beginRaffleUserResolution(isNewUser: false)

        let reloadedSettings = UserDefaultsTKAppSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloadedSettings.pendingRaffleIsNewUser, false)

        reloadedSettings.cancelPendingRaffleUserResolution()

        XCTAssertNil(reloadedSettings.raffleIsNewUser)
        XCTAssertNil(reloadedSettings.pendingRaffleIsNewUser)
    }
}
