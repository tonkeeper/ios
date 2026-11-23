@testable import KeeperCore
import XCTest

final class LoyaltyEntryTests: XCTestCase {
    func test_profileDecodesWithoutBalances() throws {
        let profile = try JSONDecoder().decode(
            LoyaltyProfile.self,
            from: Data(#"{"show_section":true,"show_banner":false}"#.utf8)
        )
        XCTAssertEqual(profile, LoyaltyProfile(showSection: true, showBanner: false, balances: []))
    }

    func test_profileDecodesTheParticipant() throws {
        let profile = try JSONDecoder().decode(
            LoyaltyProfile.self,
            from: Data(#"{"show_section":true,"show_banner":false,"participant":{"joined_at":"2026-11-01T10:00:00Z","referral_code":"r","avatar":"default-07"}}"#.utf8)
        )
        XCTAssertEqual(profile.participant, LoyaltyProfile.Participant())
        let cached = try JSONDecoder().decode(LoyaltyProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(cached, profile)
    }

    func test_entryShowsNothingWithoutTheSection() {
        let profile = LoyaltyProfile(showSection: false, showBanner: true, balances: [.init(asset: "OHM", available: "5")])
        XCTAssertEqual(LoyaltyEntry(profile: profile, isBannerHidden: false), .hidden)
        XCTAssertEqual(LoyaltyEntry(profile: nil, isBannerHidden: false), .hidden)
    }

    func test_entryTakesTheOhmBalanceOfAParticipantAndHonoursTheHiddenBanner() {
        let profile = LoyaltyProfile(
            showSection: true,
            showBanner: true,
            participant: .init(),
            balances: [.init(asset: "USD", available: "1"), .init(asset: "OHM", available: "25")]
        )
        XCTAssertEqual(
            LoyaltyEntry(profile: profile, isBannerHidden: false),
            LoyaltyEntry(showsSection: true, showsBanner: true, isJoined: true, ohms: "25")
        )
        XCTAssertEqual(
            LoyaltyEntry(profile: profile, isBannerHidden: true),
            LoyaltyEntry(showsSection: true, showsBanner: false, isJoined: true, ohms: "25")
        )
    }

    func test_entryHasNoOhmsBeforeTheJoin() {
        let profile = LoyaltyProfile(showSection: true, showBanner: true, balances: [.init(asset: "OHM", available: "25")])
        XCTAssertEqual(
            LoyaltyEntry(profile: profile, isBannerHidden: false),
            LoyaltyEntry(showsSection: true, showsBanner: true, isJoined: false, ohms: nil)
        )
    }

    func test_entryShowsTheOhmBalanceAsTheBackendSendsIt() {
        for available in ["0", "-5", "abc"] {
            let profile = LoyaltyProfile(
                showSection: true,
                showBanner: false,
                participant: .init(),
                balances: [.init(asset: "OHM", available: available)]
            )
            XCTAssertEqual(LoyaltyEntry(profile: profile, isBannerHidden: false).ohms, available)
        }
    }

    func test_volumeIsCutToCentsNeverRoundedUpAcrossAStep() {
        XCTAssertEqual(LoyaltyStore.volumeString(199.996), "199.99")
        XCTAssertEqual(LoyaltyStore.volumeString(99.999), "99.99")
        XCTAssertEqual(LoyaltyStore.volumeString(540), "540")
        XCTAssertEqual(LoyaltyStore.volumeString(143.38), "143.38")
    }

    func test_entryHasNoOhmsForABlankBalance() {
        let profile = LoyaltyProfile(
            showSection: true,
            showBanner: false,
            participant: .init(),
            balances: [.init(asset: "OHM", available: " ")]
        )
        XCTAssertNil(LoyaltyEntry(profile: profile, isBannerHidden: false).ohms)
    }
}
