@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsIntegratorReadsTests: XCTestCase {
    private actor Reads {
        private(set) var count = 0
        private var failures: Int

        init(failures: Int = 0) {
            self.failures = failures
        }

        func read() throws -> Components.Schemas.Integrator {
            count += 1
            if failures > 0 {
                failures -= 1
                throw URLError(.timedOut)
            }
            return .init(
                integrator_account_index: 7,
                integrator_taker_fee: 900,
                integrator_maker_fee: 900,
                max_perps_taker_fee: 1000,
                max_perps_maker_fee: 1000,
                max_spot_taker_fee: 0,
                max_spot_maker_fee: 0,
                approval_ttl_ms: 1000
            )
        }
    }

    func testTheReadAFormStartedAnswersEveryUseUntilItIsDropped() async throws {
        let reads = Reads()
        let integrators = PerpsIntegratorReads()
        integrators.refresh(walletId: "w") { try await reads.read() }

        _ = try await integrators.value(walletId: "w") { try await reads.read() }
        _ = try await integrators.value(walletId: "w") { try await reads.read() }
        let shared = await reads.count
        XCTAssertEqual(shared, 1)

        integrators.invalidate(walletId: "w")
        _ = try await integrators.value(walletId: "w") { try await reads.read() }
        let afterDrop = await reads.count
        XCTAssertEqual(afterDrop, 2)
    }

    func testAFailedReadIsNotKept() async throws {
        let reads = Reads(failures: 1)
        let integrators = PerpsIntegratorReads()

        do {
            _ = try await integrators.value(walletId: "w") { try await reads.read() }
            XCTFail("the first read fails")
        } catch {}
        let integrator = try await integrators.value(walletId: "w") { try await reads.read() }

        XCTAssertEqual(integrator.integrator_account_index, 7)
        let count = await reads.count
        XCTAssertEqual(count, 2)
    }

    func testEachWalletHasItsOwnRead() async throws {
        let reads = Reads()
        let integrators = PerpsIntegratorReads()

        _ = try await integrators.value(walletId: "a") { try await reads.read() }
        _ = try await integrators.value(walletId: "b") { try await reads.read() }

        let count = await reads.count
        XCTAssertEqual(count, 2)
    }
}
