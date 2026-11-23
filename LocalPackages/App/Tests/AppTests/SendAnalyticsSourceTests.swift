@testable import App
import KeeperCore
import XCTest

final class SendAnalyticsSourceTests: XCTestCase {
    func testQrCodeSourceCarriesTheScannedLinkUtm() {
        let utm = UtmParameters(link: "tonkeeper://transfer/EQD?amount=1&utm_source=poster&utm_campaign=expo")
        let source = SendAnalyticsSource.qrCode(utm: utm)

        XCTAssertEqual(source.utm, utm)
        XCTAssertEqual(source.transactionOrigin.utm, utm)
        XCTAssertEqual(source.initiatedBy, .qrCode)
        XCTAssertEqual(source.redSourceValue, "qr_code")
        XCTAssertEqual(source.sendOpenFrom, .qrCode)
    }

    func testQrCodeSourceWithoutCampaignStaysEmpty() {
        XCTAssertTrue(SendAnalyticsSource.qrCode(utm: .empty).utm.isEmpty)
        XCTAssertTrue(SendAnalyticsSource.qrCode(utm: .empty).transactionOrigin.utm.isEmpty)
    }
}
