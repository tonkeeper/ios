@testable import App
import TKCore
import XCTest

@MainActor
final class EarnDappSessionTests: XCTestCase {
    func test_closeReportsTheExitMethodAndTheTimeSinceTheTap() {
        let spy = AnalyticsServiceSpy()
        var now = Date(timeIntervalSince1970: 1000)
        let session = makeSession(spy: spy, now: { now })

        now.addTimeInterval(42)
        session.close(via: .page)

        XCTAssertEqual(spy.events.map(\.name), ["earn_close"])
        XCTAssertEqual(spy.events.first?.args["from"] as? String, "earn_featured")
        XCTAssertEqual(spy.events.first?.args["exit_method"] as? String, "page")
        XCTAssertEqual(spy.events.first?.args["duration_ms"] as? Int, 42000)
    }

    func test_onlyTheFirstCloseIsReported() {
        let spy = AnalyticsServiceSpy()
        let session = makeSession(spy: spy, now: Date.init)

        session.close(via: .closeButton)
        session.close(via: .other)

        XCTAssertEqual(spy.events.map(\.name), ["earn_close"])
        XCTAssertEqual(spy.events.first?.args["exit_method"] as? String, "close_button")
    }
}

private extension EarnDappSessionTests {
    func makeSession(spy: AnalyticsServiceSpy, now: @escaping () -> Date) -> EarnDappSession {
        let coreAssembly = TKCore.CoreAssembly()
        let analyticsProvider = AnalyticsProvider(
            analyticsServices: [spy],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
        return EarnDappSession(
            analyticsProvider: analyticsProvider,
            openSession: DappOpenAnalyticsSession(
                context: DappOpenAnalyticsContext(
                    from: .earnFeatured,
                    urlDomain: "vaults.fyi",
                    assetChain: .multichain,
                    appId: "vaults.fyi",
                    bannerId: nil,
                    location: "US"
                ),
                analyticsProvider: analyticsProvider,
                now: now
            ),
            dappUrl: "vaults.fyi"
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}
