@testable import App
import TKCore
import XCTest

final class DappOpenAnalyticsSessionTests: XCTestCase {
    func test_loadReportsHowLongTheDappTookSinceTheTap() {
        let spy = AnalyticsServiceSpy()
        var now = Date(timeIntervalSince1970: 1000)
        let session = makeSession(spy: spy, now: { now })

        session.logClick()
        now.addTimeInterval(1.5)
        session.logLoaded()

        XCTAssertEqual(spy.events.map(\.name), ["dapp_app_click", "dapp_app_loaded"])
        XCTAssertEqual(spy.events.last?.args["load_duration_ms"] as? Int, 1500)
        XCTAssertEqual(session.millisecondsSinceClick(), 1500)
    }

    func test_failedLoadEndsTheOpenInsteadOfLoaded() {
        let spy = AnalyticsServiceSpy()
        var now = Date(timeIntervalSince1970: 1000)
        let session = makeSession(spy: spy, now: { now })

        session.logClick()
        now.addTimeInterval(2)
        session.logLoadFailed(errorCode: "http_error", httpStatus: 502)
        session.logLoaded()

        XCTAssertEqual(spy.events.map(\.name), ["dapp_app_click", "dapp_app_load_failed"])
        let args = spy.events.last?.args
        XCTAssertEqual(args?["error_code"] as? String, "http_error")
        XCTAssertEqual(args?["http_status"] as? Int, 502)
        XCTAssertEqual(args?["load_duration_ms"] as? Int, 2000)
    }

    func test_failureAfterTheLoadIsNotReported() {
        let spy = AnalyticsServiceSpy()
        let session = makeSession(spy: spy, now: Date.init)

        session.logClick()
        session.logLoaded()
        session.logLoadFailed(errorCode: "NSURLErrorDomain:-1009", httpStatus: nil)

        XCTAssertEqual(spy.events.map(\.name), ["dapp_app_click", "dapp_app_loaded"])
    }

    func test_loadWithoutATapCountsFromTheStartOfTheSession() {
        let spy = AnalyticsServiceSpy()
        var now = Date(timeIntervalSince1970: 1000)
        let session = makeSession(spy: spy, now: { now })

        now.addTimeInterval(0.25)
        session.logLoaded()

        XCTAssertEqual(spy.events.map(\.name), ["dapp_app_loaded"])
        XCTAssertEqual(spy.events.first?.args["load_duration_ms"] as? Int, 250)
    }
}

private extension DappOpenAnalyticsSessionTests {
    func makeSession(spy: AnalyticsServiceSpy, now: @escaping () -> Date) -> DappOpenAnalyticsSession {
        let coreAssembly = TKCore.CoreAssembly()
        return DappOpenAnalyticsSession(
            context: DappOpenAnalyticsContext(
                from: .earnFeatured,
                urlDomain: "vaults.fyi",
                assetChain: .multichain,
                appId: "vaults.fyi",
                bannerId: nil,
                location: "US"
            ),
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [spy],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            ),
            now: now
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}
