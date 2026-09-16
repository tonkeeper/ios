@testable import App
import UserNotifications
import XCTest

/// The onboarding step is the only place an add-wallet flow asks for push permission, and it has to
/// stay where the ask can still change something: a wallet added with the permission already
/// granted is subscribed on its own, so a second prompt would be a screen that does nothing.
final class OnboardingNotificationsStepTests: XCTestCase {
    func test_undecidedPermission_isAsked() {
        XCTAssertTrue(OnboardingNotificationsStep.isNeeded(authorizationStatus: .notDetermined))
    }

    func test_grantedPermission_isNotAsked() {
        XCTAssertFalse(OnboardingNotificationsStep.isNeeded(authorizationStatus: .authorized))
    }

    /// The system never prompts twice, so a denied permission can only be changed in system
    /// settings — the balance setup step is what links there.
    func test_deniedPermission_isNotAsked() {
        XCTAssertFalse(OnboardingNotificationsStep.isNeeded(authorizationStatus: .denied))
    }

    func test_promptlessGrants_areNotAsked() {
        XCTAssertFalse(OnboardingNotificationsStep.isNeeded(authorizationStatus: .provisional))
        XCTAssertFalse(OnboardingNotificationsStep.isNeeded(authorizationStatus: .ephemeral))
    }
}
