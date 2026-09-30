@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class BootConfigurationDomainTests: XCTestCase {
    func testDecodesPerChainExplorers() throws {
        let configuration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(
                """
                {
                  "explorers": [
                    {
                      "chain": "eth",
                      "name": "Blockscout",
                      "url": "https://eth.blockscout.com/tx/{tx_hash}",
                      "token_url": "https://eth.blockscout.com/token/{token_address}"
                    },
                    {
                      "chain": "btc",
                      "name": "Mempool",
                      "url": "https://mempool.space/tx/{tx_hash}"
                    }
                  ]
                }
                """.utf8
            )
        )

        XCTAssertEqual(configuration.explorers.map(\.chain), ["eth", "btc"])
        XCTAssertEqual(configuration.explorers.first?.name, "Blockscout")
        XCTAssertEqual(configuration.explorers.first?.tokenURL, "https://eth.blockscout.com/token/{token_address}")
        XCTAssertNil(configuration.explorers.last?.tokenURL)
    }

    func testUsesNoExplorersWhenResponseDoesNotContainThem() throws {
        let configuration = try JSONDecoder().decode(BootConfiguration.self, from: Data("{}".utf8))

        XCTAssertTrue(configuration.explorers.isEmpty)
    }

    func testDecodesTheAnalyticsEndpoint() throws {
        let configuration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(#"{"aptabase_endpoint": "https://block-analytics.tonkeeper.com"}"#.utf8)
        )

        XCTAssertEqual(configuration.aptabaseEndpoint, "https://block-analytics.tonkeeper.com")
    }

    /// Absent means the bundled endpoint stands, so this must stay nil rather than gain a default.
    func testLeavesTheAnalyticsEndpointUnsetWhenTheResponseOmitsIt() throws {
        let configuration = try JSONDecoder().decode(BootConfiguration.self, from: Data("{}".utf8))

        XCTAssertNil(configuration.aptabaseEndpoint)
    }

    func testBundledDefaultConfigurationShipsMainnetExplorers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = BootConfigurationRepositoryImplementation(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: directory)
        )

        let configurations = try repository.configuration

        XCTAssertEqual(
            configurations.mainnet.explorers.map(\.chain),
            ["ton", "eth", "btc", "bsc", "arb", "base", "tron"]
        )
        XCTAssertTrue(
            configurations.mainnet.explorers.allSatisfy { $0.url.contains("{tx_hash}") }
        )
        XCTAssertTrue(
            configurations.mainnet.explorers
                .compactMap(\.tokenURL)
                .allSatisfy { $0.contains("{token_address}") }
        )
        XCTAssertNil(
            configurations.mainnet.explorers.first { $0.chain == "btc" }?.tokenURL
        )
    }

    func testDecodesConfiguredMultichainAndTradingDomains() throws {
        let configuration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(
                """
                {
                  "multichain": {
                    "domain": "https://block-multi.tonkeeper.com",
                    "realtime": "wss://block-rt.tonkeeper.com/connection/websocket"
                  },
                  "trading": {
                    "domain": "https://trading.tonkeeper.com"
                  }
                }
                """.utf8
            )
        )

        XCTAssertEqual(configuration.multichain.domain, URL(string: "https://block-multi.tonkeeper.com"))
        XCTAssertEqual(
            configuration.multichain.realtime,
            URL(string: "wss://block-rt.tonkeeper.com/connection/websocket"),
            "the realtime host is swapped by region just like the domain is"
        )
        XCTAssertEqual(configuration.trading.domain, URL(string: "https://trading.tonkeeper.com"))
        XCTAssertNil(configuration.trading.realtime)
    }

    func testKeepsDefaultRealtimeWhenTheEndpointOmitsIt() throws {
        let configuration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(
                """
                { "multichain": { "domain": "https://block-multi.tonkeeper.com" } }
                """.utf8
            )
        )

        XCTAssertEqual(configuration.multichain.domain, URL(string: "https://block-multi.tonkeeper.com"))
        XCTAssertNil(configuration.multichain.realtime)
    }

    func testUsesDefaultDomainsWhenResponseDoesNotContainEndpoints() throws {
        let configuration = try JSONDecoder().decode(BootConfiguration.self, from: Data("{}".utf8))

        XCTAssertEqual(configuration.multichain.domain, URL(string: "https://multi.tonkeeper.com"))
        XCTAssertEqual(configuration.multichain.realtime, BootConfiguration.defaultMultichainRealtimeURL)
        XCTAssertEqual(configuration.trading.domain, URL(string: "https://trading.tonkeeper.com"))
    }
}
