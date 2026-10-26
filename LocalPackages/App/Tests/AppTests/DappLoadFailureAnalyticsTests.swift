@testable import App
import TKScreenKit
import XCTest

final class DappLoadFailureAnalyticsTests: XCTestCase {
    func test_networkFailureCarriesTheDomainAndCodeOfTheError() {
        let failure = TKBridgeWebViewController.LoadFailure.network(domain: NSURLErrorDomain, code: -1009)

        XCTAssertEqual(failure.errorCode, "NSURLErrorDomain:-1009")
        XCTAssertNil(failure.httpStatus)
    }

    func test_httpErrorCarriesItsStatus() {
        let failure = TKBridgeWebViewController.LoadFailure.httpError(status: 404)

        XCTAssertEqual(failure.errorCode, "http_error")
        XCTAssertEqual(failure.httpStatus, 404)
    }

    func test_terminatedProcessHasACodeOfItsOwn() {
        let failure = TKBridgeWebViewController.LoadFailure.processTerminated

        XCTAssertEqual(failure.errorCode, "web_content_process_terminated")
        XCTAssertNil(failure.httpStatus)
    }
}
