@testable import App
import KeeperCore
import XCTest

final class HomeBannerMysteryRaffleTests: XCTestCase {
    func test_recognizesRaffleBannerNamespace() {
        XCTAssertTrue(banner(id: "mystery_raffle").isMysteryRaffleBanner)
        XCTAssertTrue(banner(id: "mystery_raffle_second_phase").isMysteryRaffleBanner)
    }

    func test_rejectsUnrelatedBanner() {
        XCTAssertFalse(banner(id: "battery").isMysteryRaffleBanner)
    }

    private func banner(id: String) -> HomeBanner {
        HomeBanner(
            id: id,
            title: "",
            description: "",
            image: nil,
            textColor: nil,
            backgroundColor: nil,
            button: nil
        )
    }
}
