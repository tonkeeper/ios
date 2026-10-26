import Foundation
@testable import KeeperCore
import TKBatteryAPI
import XCTest

/// Which EVM chains the relayer's config turns into relayed engines, and how the config is kept.
final class EVMGaslessRelayedChainsTests: XCTestCase {
    func test_onlyEVMChainsThatTakeAMainPayloadAreRelayed() {
        let config = Components.Schemas.GaslessV2Config(chains: [
            chain("ton/mainnet"),
            chain("eth/mainnet"),
            chain("bsc/mainnet", payloadTypes: ["prebuild"]),
            chain("arb/mainnet", payloadTypes: ["main", "prebuild"]),
            chain("base/mainnet"),
            chain("sol/mainnet"),
            chain("eth/sepolia"),
            chain("polygon/mainnet"),
            chain("optimism/mainnet"),
        ])

        XCTAssertEqual(EVMGaslessRelayedChains.relayedEVMChains(in: config), [.eth, .arb, .base, .polygon])
    }

    func test_theConfigIsReadOnceWhileItLasts() async {
        let loader = ConfigLoader(results: [.success(config(.eth)), .success(config(.base))])
        let chains = EVMGaslessRelayedChains(loadConfig: { try await loader.load() })

        let first = await chains.chains()
        let second = await chains.chains()

        XCTAssertEqual(first, [.eth])
        XCTAssertEqual(second, [.eth])
        let loads = await loader.loads
        XCTAssertEqual(loads, 1)
    }

    func test_anExpiredConfigIsReadAgain() async {
        let loader = ConfigLoader(results: [.success(config(.eth)), .success(config(.eth, .base))])
        var now = Date(timeIntervalSince1970: 1000)
        let chains = EVMGaslessRelayedChains(loadConfig: { try await loader.load() }, lifetime: 60, now: { now })

        let fresh = await chains.chains()
        now = now.addingTimeInterval(59)
        let kept = await chains.chains()
        now = now.addingTimeInterval(1)
        let reread = await chains.chains()

        XCTAssertEqual(fresh, [.eth])
        XCTAssertEqual(kept, [.eth])
        XCTAssertEqual(reread, [.eth, .base])
    }

    func test_aConfigThatCannotBeReadLeavesTheLastOneInForce() async {
        let loader = ConfigLoader(results: [.success(config(.eth)), .failure(URLError(.notConnectedToInternet))])
        var now = Date(timeIntervalSince1970: 1000)
        let chains = EVMGaslessRelayedChains(loadConfig: { try await loader.load() }, lifetime: 60, now: { now })

        _ = await chains.chains()
        now = now.addingTimeInterval(61)
        let afterFailure = await chains.chains()

        XCTAssertEqual(afterFailure, [.eth])
    }

    func test_nothingIsKnownUntilAConfigArrives() async {
        let loader = ConfigLoader(results: [.failure(URLError(.timedOut)), .success(config(.arb))])
        let chains = EVMGaslessRelayedChains(loadConfig: { try await loader.load() })

        let unknown = await chains.chains()
        let known = await chains.chains()

        XCTAssertNil(unknown)
        XCTAssertEqual(known, [.arb])
        let loads = await loader.loads
        XCTAssertEqual(loads, 2)
    }

    func test_concurrentReadersShareOneLoad() async {
        let gate = Gate()
        let loader = ConfigLoader(results: [.success(config(.eth))], gate: gate)
        let chains = EVMGaslessRelayedChains(loadConfig: { try await loader.load() })

        async let first = chains.chains()
        async let second = chains.chains()
        await gate.open()
        let results = await[first, second]

        XCTAssertEqual(results, [[.eth], [.eth]])
        let loads = await loader.loads
        XCTAssertEqual(loads, 1)
    }
}

private extension EVMGaslessRelayedChainsTests {
    func chain(_ id: String, payloadTypes: [String] = ["main"]) -> Components.Schemas.GaslessV2Chain {
        Components.Schemas.GaslessV2Chain(chain_id: id, payload_types: payloadTypes, assets: [])
    }

    func config(_ chains: MultichainChain...) -> Components.Schemas.GaslessV2Config {
        Components.Schemas.GaslessV2Config(chains: chains.map { chain($0.relayerChainId) })
    }
}

private actor ConfigLoader {
    private var results: [Result<Components.Schemas.GaslessV2Config, Error>]
    private let gate: Gate?
    private(set) var loads = 0

    init(results: [Result<Components.Schemas.GaslessV2Config, Error>], gate: Gate? = nil) {
        self.results = results
        self.gate = gate
    }

    func load() async throws -> Components.Schemas.GaslessV2Config {
        loads += 1
        let result = results.isEmpty ? .failure(URLError(.badServerResponse)) : results.removeFirst()
        await gate?.wait()
        return try result.get()
    }
}

/// Holds callers until opened; opening before anyone waits lets them all through.
private actor Gate {
    private var isOpen = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiters = self.waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}
