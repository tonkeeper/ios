@testable import KeeperCore
import XCTest

final class TronChainParametersRepositoryTests: XCTestCase {
    private let fees = TronChainFees(
        energySun: 210,
        bandwidthSun: 1000,
        createAccountSun: 100_000,
        createNewAccountSun: 1_000_000,
        createNewAccountBandwidthRate: 1
    )

    func test_pricesAreServedWhileFresh() async {
        let clock = Clock()
        let repository = TronChainParametersRepositoryImplementation(
            lifetime: 600,
            now: { clock.now }
        )

        await repository.setChainFees(fees)
        clock.advance(by: 599)

        let cached = await repository.chainFees()
        XCTAssertEqual(cached?.energySun, 210)
    }

    /// TK-2647: a cache without expiry keeps quoting the pre-raise energy price all session.
    func test_pricesExpireAfterLifetime() async {
        let clock = Clock()
        let repository = TronChainParametersRepositoryImplementation(
            lifetime: 600,
            now: { clock.now }
        )

        await repository.setChainFees(fees)
        clock.advance(by: 600)

        let cached = await repository.chainFees()
        XCTAssertNil(cached)
    }

    func test_pricesAreEmptyBeforeFirstLoad() async {
        let repository = TronChainParametersRepositoryImplementation()

        let cached = await repository.chainFees()
        XCTAssertNil(cached)
    }

    func test_refreshExtendsLifetime() async {
        let clock = Clock()
        let repository = TronChainParametersRepositoryImplementation(
            lifetime: 600,
            now: { clock.now }
        )

        await repository.setChainFees(fees)
        clock.advance(by: 599)
        await repository.setChainFees(fees)
        clock.advance(by: 599)

        let cached = await repository.chainFees()
        XCTAssertNotNil(cached)
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_785_000_000)

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        date = date.addingTimeInterval(seconds)
    }
}
