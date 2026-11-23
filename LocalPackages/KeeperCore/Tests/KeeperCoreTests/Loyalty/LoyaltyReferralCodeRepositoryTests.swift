@testable import KeeperCore
import XCTest

final class LoyaltyReferralCodeRepositoryTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "LoyaltyReferralCodeRepositoryTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    @MainActor
    func test_aPendingCodeIsNotReplacedByALaterLink() {
        let repository = LoyaltyReferralCodeRepository(userDefaults: defaults)

        repository.save("first")
        repository.save("second")

        XCTAssertEqual(repository.take(), "first")
    }

    @MainActor
    func test_thePendingCodeIsReadWithoutTakingIt() {
        let repository = LoyaltyReferralCodeRepository(userDefaults: defaults)

        XCTAssertNil(repository.pendingCode)
        repository.save("first")

        XCTAssertEqual(repository.pendingCode, "first")
        XCTAssertEqual(repository.take(), "first")
        XCTAssertNil(repository.pendingCode)
    }

    @MainActor
    func test_takeHandsTheCodeOutOnce() {
        let repository = LoyaltyReferralCodeRepository(userDefaults: defaults)

        repository.save("first")

        XCTAssertEqual(repository.take(), "first")
        XCTAssertNil(repository.take())
    }

    @MainActor
    func test_aLinkAfterTheCodeWasTakenIsKept() {
        let repository = LoyaltyReferralCodeRepository(userDefaults: defaults)

        repository.save("first")
        _ = repository.take()
        repository.save("second")

        XCTAssertEqual(LoyaltyReferralCodeRepository(userDefaults: defaults).take(), "second")
    }
}
