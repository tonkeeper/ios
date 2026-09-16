import Foundation
@testable import KeeperCore
import XCTest

final class TronMigrationBalanceCacheTests: XCTestCase {
    func test_returnsStoredBalanceWithinTtl() async {
        let cache = TronMigrationBalanceCache(ttl: 60)
        let balance = TronBalance(amount: 5, trxAmount: 7)

        await cache.store(balance, for: "address")
        let cached = await cache.freshBalance(for: "address")

        XCTAssertEqual(cached, balance)
    }

    func test_missesForUnknownAddress() async {
        let cache = TronMigrationBalanceCache(ttl: 60)

        let cached = await cache.freshBalance(for: "unknown")

        XCTAssertNil(cached)
    }

    func test_expiresAfterTtl() async {
        let cache = TronMigrationBalanceCache(ttl: 0)
        let balance = TronBalance(amount: 5, trxAmount: 7)

        await cache.store(balance, for: "address")
        let fresh = await cache.freshBalance(for: "address")
        let lastKnown = await cache.lastKnownBalance(for: "address")

        XCTAssertNil(fresh)
        XCTAssertEqual(lastKnown, balance)
    }

    func test_successfulZeroReplacesLastKnownBalance() async {
        let cache = TronMigrationBalanceCache(ttl: 60)
        let zero = TronBalance(amount: 0, trxAmount: 0)

        await cache.store(TronBalance(amount: 5, trxAmount: 7), for: "address")
        await cache.store(zero, for: "address")

        let fresh = await cache.freshBalance(for: "address")
        let lastKnown = await cache.lastKnownBalance(for: "address")
        XCTAssertEqual(fresh, zero)
        XCTAssertEqual(lastKnown, zero)
    }
}
