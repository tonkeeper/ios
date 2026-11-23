@testable import App
import MoonPay
import XCTest

final class RampConnectivityTests: XCTestCase {
    func test_offlineErrors_areURLSessionsNoNetworkCodes_alsoInsideMoonPaysTransportError() {
        XCTAssertTrue(RampConnectivity.isOfflineError(URLError(.notConnectedToInternet)))
        XCTAssertTrue(RampConnectivity.isOfflineError(URLError(.networkConnectionLost)))
        XCTAssertTrue(RampConnectivity.isOfflineError(MoonPayAPIError.transport(URLError(.notConnectedToInternet))))
        XCTAssertTrue(RampConnectivity.isOfflineError(MoonPayAPIError.transport(URLError(.dataNotAllowed))))
    }

    func test_otherErrors_areNotOffline() {
        XCTAssertFalse(RampConnectivity.isOfflineError(URLError(.timedOut)))
        XCTAssertFalse(RampConnectivity.isOfflineError(URLError(.cancelled)))
        XCTAssertFalse(RampConnectivity.isOfflineError(MoonPayAPIError.transport(URLError(.badServerResponse))))
        XCTAssertFalse(RampConnectivity.isOfflineError(MoonPayAPIError.http(status: 500, body: nil)))
        XCTAssertFalse(RampConnectivity.isOfflineError(CancellationError()))
    }
}
