@testable import TKCore
import XCTest

final class AptabaseEndpointStateTests: XCTestCase {
    private let bundled = "https://bundled.example.com"
    private let cached = "https://cached.example.com"
    private let remote = "https://remote.example.com"

    func test_missingOrInvalidRemoteRestoresBundledEndpoint() {
        for endpoint in [nil, "not a url"] as [String?] {
            var state = AptabaseConfigurator.EndpointState(active: cached)
            XCTAssertEqual(state.request(endpoint, bundledEndpoint: bundled), bundled)
            XCTAssertEqual(state.active, bundled)
        }
    }

    func test_cachedEndpointAppliesBeforePollingStarts() {
        var state = AptabaseConfigurator.EndpointState(active: bundled)
        XCTAssertEqual(state.request(cached, bundledEndpoint: bundled), cached)
        XCTAssertNil(state.request(cached, bundledEndpoint: bundled))
    }

    func test_returnToActiveEndpointCancelsDeferredChange() {
        var state = AptabaseConfigurator.EndpointState(active: bundled, isPolling: true)
        XCTAssertNil(state.request(cached, bundledEndpoint: bundled))
        XCTAssertNil(state.request(bundled, bundledEndpoint: bundled))
        state.isPolling = false
        XCTAssertNil(state.applyPending())
        XCTAssertEqual(state.active, bundled)
    }

    func test_onlyLatestDeferredEndpointAppliesAfterPollingStops() {
        var state = AptabaseConfigurator.EndpointState(active: bundled, isPolling: true)
        XCTAssertNil(state.request(cached, bundledEndpoint: bundled))
        XCTAssertNil(state.request(remote, bundledEndpoint: bundled))
        XCTAssertNil(state.applyPending())
        XCTAssertEqual(state.active, bundled)
        state.isPolling = false
        XCTAssertEqual(state.applyPending(), remote)
        XCTAssertNil(state.applyPending())
    }

    func test_missingRemoteReplacesDeferredEndpointWithBundledHost() {
        var state = AptabaseConfigurator.EndpointState(active: cached, isPolling: true)
        XCTAssertNil(state.request(remote, bundledEndpoint: bundled))
        XCTAssertNil(state.request(nil, bundledEndpoint: bundled))
        state.isPolling = false
        XCTAssertEqual(state.applyPending(), bundled)
    }

    func test_foregroundBeforeDeferredCallbackKeepsChangePending() {
        var state = AptabaseConfigurator.EndpointState(active: bundled, isPolling: true)
        XCTAssertNil(state.request(remote, bundledEndpoint: bundled))
        state.isPolling = false
        state.isPolling = true
        XCTAssertNil(state.applyPending())
        state.isPolling = false
        XCTAssertEqual(state.applyPending(), remote)
    }
}
