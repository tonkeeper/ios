import Foundation
@testable import TKCore
@testable import TKServices
import XCTest

final class ResolvedDeeplinkBufferTests: XCTestCase {
    func test_coldStartRoutesTheResolvedSwapLinkAfterTheOriginalURL() {
        var buffer = ResolvedDeeplinkBuffer()
        buffer.beginCoalescing()
        buffer.markDelivered("https://go.tonkeeper.com/campaign")
        XCTAssertEqual(buffer.receive("tonkeeper://swap?ft=TON&tt=USDT"), [])
        XCTAssertEqual(buffer.attachRouter(), [])

        XCTAssertEqual(buffer.endCoalescing(), ["tonkeeper://swap?ft=TON&tt=USDT"])
        XCTAssertEqual(buffer.receive("https://go.tonkeeper.com/campaign"), [])
        XCTAssertEqual(buffer.receive("https://app.tonkeeper.com/swap?tt=USDT&ft=TON"), [])
    }

    func test_equivalentSwapLinksRouteOnce() {
        var buffer = ResolvedDeeplinkBuffer()
        _ = buffer.attachRouter()

        XCTAssertEqual(
            buffer.receive("https://app.tonkeeper.com/swap?tt=USDT&ft=TON"),
            ["https://app.tonkeeper.com/swap?tt=USDT&ft=TON"]
        )
        XCTAssertEqual(buffer.receive("tonkeeper://swap?ft=TON&tt=USDT"), [])
        XCTAssertEqual(buffer.receive("keeper://swap?ft=TON&tt=USDT"), [])
        XCTAssertEqual(buffer.receive("https://app.tonkeeper.org/swap?ft=TON&tt=USDT"), [])
        XCTAssertEqual(buffer.receive("https://app.keeperwallet.com/swap?ft=TON&tt=USDT"), [])
        XCTAssertEqual(
            buffer.receive("tonkeeper://swap?ft=USDT&tt=TON"),
            ["tonkeeper://swap?ft=USDT&tt=TON"]
        )
    }

    func test_resolvedLinkArrivingBeforeTheSceneStaysBuffered() {
        var buffer = ResolvedDeeplinkBuffer()
        XCTAssertEqual(buffer.receive("tonkeeper://swap?ft=TON&tt=USDT"), [])

        XCTAssertEqual(buffer.attachRouter(), ["tonkeeper://swap?ft=TON&tt=USDT"])
        XCTAssertEqual(buffer.receive("tonkeeper://swap?ft=TON&tt=USDT"), [])
    }

    func test_blankLinkIsIgnored() {
        var buffer = ResolvedDeeplinkBuffer()
        _ = buffer.attachRouter()

        XCTAssertEqual(buffer.receive("   "), [])
        XCTAssertEqual(buffer.receive(nil), [])
    }
}
