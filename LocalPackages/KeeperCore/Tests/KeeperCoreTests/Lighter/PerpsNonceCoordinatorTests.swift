@testable import KeeperCore
import XCTest

final class PerpsNonceCoordinatorTests: XCTestCase {
    private let scope = PerpsNonceCoordinator.Scope(accountIndex: 42, apiKeyIndex: 3, chainId: 304)

    func testUsesOneBackendAnchorThenAdvancesLocally() async throws {
        let coordinator = PerpsNonceCoordinator()

        let first = try await coordinator.next(scope: scope) { 5 }
        let second = try await coordinator.next(scope: scope) { 99 }

        XCTAssertEqual(first, 5)
        XCTAssertEqual(second, 6)
    }

    func testResyncMakesTheNextAllocationTheBackendNonce() async throws {
        let coordinator = PerpsNonceCoordinator()

        _ = try await coordinator.next(scope: scope) { 5 }
        try await coordinator.resync(scope: scope) { 12 }

        let next = try await coordinator.next(scope: scope) { 99 }
        XCTAssertEqual(next, 12)
    }

    func testFailedResyncDropsTheOldCursor() async throws {
        enum Failure: Error { case unavailable }

        let coordinator = PerpsNonceCoordinator()
        _ = try await coordinator.next(scope: scope) { 5 }

        do {
            try await coordinator.resync(scope: scope) { throw Failure.unavailable }
            XCTFail("resync should fail")
        } catch is Failure {
            // Expected: the stale cursor must not survive a failed refresh.
        }

        let next = try await coordinator.next(scope: scope) { 20 }
        XCTAssertEqual(next, 20)
    }
}
