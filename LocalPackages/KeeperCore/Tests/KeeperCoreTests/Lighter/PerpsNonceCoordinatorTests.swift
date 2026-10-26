@testable import KeeperCore
import XCTest

final class PerpsNonceCoordinatorTests: XCTestCase {
    private let scope = PerpsNonceCoordinator.Scope(environment: "mainnet", accountIndex: 42, apiKeyIndex: 3, chainId: 304)

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

    func testAdvancingToVenueNonceNeverReusesOrRollsBackALocalNonce() async throws {
        let coordinator = PerpsNonceCoordinator()
        _ = try await coordinator.next(scope: scope) { 5 }

        try await coordinator.advance(scope: scope, nextNonce: 8)
        let first = try await coordinator.next(scope: scope) { 99 }
        try await coordinator.advance(scope: scope, nextNonce: 6)
        let second = try await coordinator.next(scope: scope) { 99 }

        XCTAssertEqual(first, 8)
        XCTAssertEqual(second, 9)
    }

    func testAnotherEnvironmentKeepsItsOwnCursor() async throws {
        let coordinator = PerpsNonceCoordinator()
        let other = PerpsNonceCoordinator.Scope(
            environment: "testnet",
            accountIndex: scope.accountIndex,
            apiKeyIndex: scope.apiKeyIndex,
            chainId: scope.chainId
        )

        _ = try await coordinator.next(scope: scope) { 5 }
        let first = try await coordinator.next(scope: other) { 100 }

        XCTAssertEqual(first, 100)
    }
}
