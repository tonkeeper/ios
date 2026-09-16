import Foundation
@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingAssetInfoSourceMappingTests: XCTestCase {
    func test_mapsDisplayedNameAndURL() {
        let source = TradingAssetInfoSource(api: Components.Schemas.AssetInfoSource(
            displayed_name: "dyor.io",
            url: "https://dyor.io/token/usdt"
        ))

        XCTAssertEqual(source.displayedName, "dyor.io")
        XCTAssertEqual(source.url, URL(string: "https://dyor.io/token/usdt"))
    }

    func test_unparsableURLLeavesSourceWithoutLink() {
        let source = TradingAssetInfoSource(api: Components.Schemas.AssetInfoSource(
            displayed_name: "dyor.io",
            url: ""
        ))

        XCTAssertEqual(source.displayedName, "dyor.io")
        XCTAssertNil(source.url)
    }
}
