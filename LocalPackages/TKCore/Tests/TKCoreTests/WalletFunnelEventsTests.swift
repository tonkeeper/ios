import Foundation
@testable import TKCore
import XCTest

final class WalletFunnelEventsTests: XCTestCase {
    func testWalletFlowEventsEncodeRequiredSources() throws {
        let create = try encode(WalletCreateSuccess(walletMode: .multi, backedUp: true, from: .onboarding))
        let menu = try encode(AddWalletMenuView(from: .main))
        let importStarted = try encode(
            WalletImportStarted(walletMode: .multi, walletSource: .mnemonic, from: .onboarding)
        )
        let importError = try encode(
            WalletImportError(
                walletMode: .single,
                walletSource: .watchonly,
                from: .main,
                errorType: nil,
                errorCode: nil,
                errorMessage: "invalid address"
            )
        )
        let backup = try encode(WalletBackupSuccess(walletMode: .single, source: .walletSetupSection))

        XCTAssertEqual(create["from"] as? String, AddWalletSource.onboarding.rawValue)
        XCTAssertEqual(create["backed_up"] as? Bool, true)
        XCTAssertEqual(menu["from"] as? String, AddWalletSource.main.rawValue)
        XCTAssertEqual(importStarted["wallet_mode"] as? String, WalletMode.multi.rawValue)
        XCTAssertEqual(importStarted["wallet_source"] as? String, WalletSource.mnemonic.rawValue)
        XCTAssertEqual(importStarted["from"] as? String, AddWalletSource.onboarding.rawValue)
        XCTAssertEqual(importError["wallet_source"] as? String, WalletSource.watchonly.rawValue)
        XCTAssertEqual(importError["from"] as? String, AddWalletSource.main.rawValue)
        XCTAssertEqual(backup["source"] as? String, BackupSource.walletSetupSection.rawValue)
    }

    func testOnboardingEventsEncodeTheirEventNames() throws {
        XCTAssertEqual(try eventName(OnboardingViewWelcome()), "onboarding_view_welcome")
        XCTAssertEqual(try eventName(OnboardingPasscodeCreated()), "onboarding_passcode_created")
        XCTAssertEqual(try eventName(OnboardingPasscodeMismatch()), "onboarding_passcode_mismatch")
        XCTAssertEqual(try eventName(OnboardingViewCustomize()), "onboarding_view_customize")
        XCTAssertEqual(try eventName(OnboardingClickCustomizeContinue()), "onboarding_click_customize_continue")
    }
}

private func encode(_ event: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(event)
    let object = try JSONSerialization.jsonObject(with: data)

    return try XCTUnwrap(object as? [String: Any])
}

private func eventName(_ event: some Encodable) throws -> String? {
    try encode(event)["eventName"] as? String
}
