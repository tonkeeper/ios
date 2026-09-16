@testable import App
import Foundation
import KeeperCore
import XCTest

final class MultichainSwapSlippageServiceTests: XCTestCase {
    func test_optionsAndDefaultUseSourceChainConfig() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/coin",
            slippage: slippage(
                chainId: "eth",
                optionsBps: [50, 100, 300],
                defaultBps: 100
            )
        )

        XCTAssertEqual(service.optionsBps, [50, 100, 300])
        XCTAssertEqual(service.defaultBps, 100)
    }

    func test_defaultFallsBackTo100WhenConfigIsMissing() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/coin",
            slippage: nil
        )

        XCTAssertEqual(service.optionsBps, [])
        XCTAssertEqual(service.defaultBps, 100)
        XCTAssertEqual(service.initialSelectedBps(route: route(totalSlippageBps: nil)), 100)
    }

    func test_initialSelectedBpsPrefersRouteSlippageWhenItIsAvailableOption() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/coin",
            slippage: slippage(
                chainId: "eth",
                optionsBps: [50, 100, 300],
                defaultBps: 100
            )
        )

        XCTAssertEqual(service.initialSelectedBps(route: route(totalSlippageBps: 300)), 300)
    }

    func test_initialSelectedBpsUsesDefaultWhenRouteSlippageIsMissing() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/coin",
            slippage: slippage(
                chainId: "eth",
                optionsBps: [50, 100, 300],
                defaultBps: 100
            )
        )

        XCTAssertEqual(service.initialSelectedBps(route: route(totalSlippageBps: nil)), 100)
    }

    func test_initialSelectedBpsUsesDefaultWhenRouteSlippageIsNotAvailableOption() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/coin",
            slippage: slippage(
                chainId: "eth",
                optionsBps: [50, 100, 300],
                defaultBps: 100
            )
        )

        XCTAssertEqual(service.initialSelectedBps(route: route(totalSlippageBps: 250)), 100)
    }

    func test_sourceAssetIdChainTakesPrecedenceOverSourceChainFallback() {
        let service = makeService(
            sourceAssetId: "eth/mainnet/erc20/0x123",
            sourceChain: .btc,
            slippage: .init(
                chains: [
                    "eth": .init(optionsBps: [100], defaultBps: 100),
                    "btc": .init(optionsBps: [500], defaultBps: 500),
                ]
            )
        )

        XCTAssertEqual(service.defaultBps, 100)
    }

    func test_sourceChainFallbackIsUsedWhenAssetIdHasNoChainId() {
        let service = makeService(
            sourceAssetId: "coin",
            sourceChain: .base,
            slippage: slippage(
                chainId: "base",
                optionsBps: [200],
                defaultBps: 200
            )
        )

        XCTAssertEqual(service.optionsBps, [200])
        XCTAssertEqual(service.defaultBps, 200)
    }
}

private extension MultichainSwapSlippageServiceTests {
    func makeService(
        sourceAssetId: String,
        sourceChain: MultichainChain? = .eth,
        slippage: MultichainSwapSlippage?
    ) -> DefaultMultichainSwapSlippageService {
        DefaultMultichainSwapSlippageService(
            sourceAssetId: sourceAssetId,
            sourceChain: sourceChain,
            slippage: slippage
        )
    }

    func slippage(
        chainId: String,
        optionsBps: [Int],
        defaultBps: Int
    ) -> MultichainSwapSlippage {
        .init(chains: [
            chainId: .init(
                optionsBps: optionsBps,
                defaultBps: defaultBps
            ),
        ])
    }

    func route(totalSlippageBps: Int?) -> MultichainSwapRoute {
        .init(
            routeId: "route",
            aggregator: "aggregator",
            protocolSlug: "protocol",
            routeType: "single",
            estimatedDestinationAmount: "100",
            minimumDestinationAmount: "99",
            totalSlippageBps: totalSlippageBps,
            legs: [],
            dateExpire: Date(timeIntervalSince1970: 1),
            riskLevel: "low"
        )
    }
}
