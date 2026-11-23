@testable import KeeperCore
import TKTestSupport
import TonSwift
import XCTest

final class WatchOnlyContractVersionResolverTests: XCTestCase {
    private let address = Address(workchain: 0, hash: Data(repeating: 1, count: 32))

    func test_wallet_tg_interface_is_recognised() async {
        let loader = AccountLoaderStub(status: "active", interfaces: ["walletTg"])

        let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

        XCTAssertEqual(version, .walletTg)
    }

    func test_regular_wallet_interfaces_are_recognised() async {
        let versions: [(interface: String, version: WalletContractVersion)] = [
            ("wallet_v3r1", .v3R1),
            ("wallet_v3r2", .v3R2),
            ("wallet_v4r1", .v4R1),
            ("wallet_v4r2", .v4R2),
            ("wallet_v5_beta", .v5Beta),
            ("wallet_v5", .v5R1),
            ("wallet_v5r1", .v5R1),
        ]

        for (interface, expected) in versions {
            let loader = AccountLoaderStub(status: "active", interfaces: [interface])

            let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

            XCTAssertEqual(version, expected, interface)
        }
    }

    func test_other_interface_is_not_recognised() async {
        let loader = AccountLoaderStub(status: "active", interfaces: ["wallet_highload_v3r1"])

        let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

        XCTAssertNil(version)
    }

    func test_account_without_interfaces_is_not_recognised() async {
        let loader = AccountLoaderStub(status: "uninit", balance: 1)

        let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

        XCTAssertNil(version)
    }

    func test_wallet_tg_interface_wins_over_a_regular_interface_of_the_same_account() async {
        let loader = AccountLoaderStub(status: "active", interfaces: ["walletTg", "wallet_v4r2"])

        let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

        XCTAssertEqual(version, .walletTg)
    }

    func test_failed_request_leaves_the_version_unknown() async {
        let loader = AccountLoaderStub(error: URLError(.notConnectedToInternet))

        let version = await makeResolver(loader: loader).contractVersion(address: address, network: .mainnet)

        XCTAssertNil(version)
    }

    func test_stalled_request_leaves_the_version_unknown_after_the_time_limit() async {
        let gate = TestGate()
        let loader = AccountLoaderStub(status: "active", interfaces: ["walletTg"], accountGate: gate)

        let version = await makeResolver(loader: loader, timeLimit: 0)
            .contractVersion(address: address, network: .mainnet)
        await gate.open()

        XCTAssertNil(version)
    }

    func test_cancelled_lookup_returns_without_a_version() async {
        let gate = TestGate()
        let loader = AccountLoaderStub(status: "active", interfaces: ["walletTg"], accountGate: gate)
        let resolver = makeResolver(loader: loader)
        let address = address

        let lookup = Task { await resolver.contractVersion(address: address, network: .mainnet) }
        lookup.cancel()
        let version = await lookup.value
        await gate.open()

        XCTAssertNil(version)
    }
}

private extension WatchOnlyContractVersionResolverTests {
    func makeResolver(
        loader: AccountLoaderStub,
        timeLimit: TimeInterval = WatchOnlyContractVersionResolver.defaultTimeLimit
    ) -> WatchOnlyContractVersionResolver {
        WatchOnlyContractVersionResolver(
            accountLoader: loader,
            timeLimit: timeLimit
        )
    }
}
