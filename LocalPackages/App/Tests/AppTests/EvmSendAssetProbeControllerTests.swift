@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class EvmSendAssetProbeControllerTests: XCTestCase {
    private let recipient = "0x8e23ee67d1332ad560396262c48ffbb01f93d052"
    private let usdt = "0xdac17f958d2ee523a2206206994597c13d831ec7"

    func test_pinnedChainResolvesNativeAsset() async {
        let asset = makeAsset(assetId: "eth/mainnet/coin")
        let controller = makeController(known: [asset])

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .native, chain: .eth),
            multichainState: makeState(chains: [.eth, .base])
        )

        XCTAssertEqual(resolution, .send(asset: asset, chain: .eth))
    }

    func test_pinnedChainResolvesErc20ByLowercasedContract() async {
        let asset = makeAsset(assetId: "eth/mainnet/erc20/\(usdt)")
        var requestedIds = [String]()
        let controller = makeController(known: [asset], onRequest: { requestedIds.append($0) })

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt.uppercased()), chain: .eth),
            multichainState: makeState(chains: [.eth])
        )

        XCTAssertEqual(resolution, .send(asset: asset, chain: .eth))
        XCTAssertEqual(requestedIds, ["eth/mainnet/erc20/\(usdt)"])
    }

    func test_pinnedChainMissingFromWalletIsUnsupported() async {
        let resolution = await makeController(known: []).resolve(
            transfer: makeTransfer(asset: .native, chain: .arb),
            multichainState: makeState(chains: [.eth, .base])
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_walletWithoutEvmChainsIsUnsupported() async {
        let resolution = await makeController(known: []).resolve(
            transfer: makeTransfer(asset: .native, chain: .eth),
            multichainState: makeState(chains: [.ton, .tron, .btc])
        )

        XCTAssertEqual(resolution, .unsupported)
    }

    func test_pinnedChainWithUnresolvableAssetReportsAssetUnavailable() async {
        let resolution = await makeController(known: []).resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: .eth),
            multichainState: makeState(chains: [.eth])
        )

        XCTAssertEqual(resolution, .assetUnavailable)
    }

    func test_pinnedChainWithUntransferableAssetReportsAssetUnavailable() async {
        let asset = makeAsset(assetId: "eth/mainnet/erc20/\(usdt)")
        let controller = makeController(known: [asset], isTransferSupported: { _ in false })

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: .eth),
            multichainState: makeState(chains: [.eth])
        )

        XCTAssertEqual(resolution, .assetUnavailable)
    }

    func test_singleProbeHitResolvesChain() async {
        let asset = makeAsset(assetId: "base/mainnet/erc20/\(usdt)")
        let controller = makeController(known: [asset])

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: nil),
            multichainState: makeState(chains: [.eth, .base, .arb])
        )

        XCTAssertEqual(resolution, .send(asset: asset, chain: .base))
    }

    func test_multipleProbeHitsOpenPickerFilteredToMatchedChains() async {
        let controller = makeController(known: [
            makeAsset(assetId: "eth/mainnet/erc20/\(usdt)"),
            makeAsset(assetId: "arb/mainnet/erc20/\(usdt)"),
        ])

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: nil),
            multichainState: makeState(chains: [.eth, .base, .arb])
        )

        XCTAssertEqual(resolution, .picker(allowedChains: [.eth, .arb]))
    }

    func test_noProbeHitsOpensPickerOverWalletEvmChains() async {
        let resolution = await makeController(known: []).resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: nil),
            multichainState: makeState(chains: [.ton, .eth, .base, .btc])
        )

        XCTAssertEqual(resolution, .picker(allowedChains: [.eth, .base]))
    }

    func test_nativeWithoutChainIdIsNotProbed() async {
        var requestedIds = [String]()
        let controller = makeController(
            known: [makeAsset(assetId: "eth/mainnet/coin")],
            onRequest: { requestedIds.append($0) }
        )

        let resolution = await controller.resolve(
            transfer: makeTransfer(asset: .native, chain: nil),
            multichainState: makeState(chains: [.eth, .base])
        )

        XCTAssertEqual(resolution, .picker(allowedChains: [.eth, .base]))
        XCTAssertEqual(requestedIds, [])
    }

    func test_probeVisitsEachWalletEvmChainOnce() async {
        var requestedIds = [String]()
        let controller = makeController(known: [], onRequest: { requestedIds.append($0) })

        _ = await controller.resolve(
            transfer: makeTransfer(asset: .erc20(contract: usdt), chain: nil),
            multichainState: makeState(chains: [.eth, .ton, .eth, .bsc])
        )

        XCTAssertEqual(
            requestedIds,
            ["eth/mainnet/erc20/\(usdt)", "bsc/mainnet/erc20/\(usdt)"]
        )
    }
}

private extension EvmSendAssetProbeControllerTests {
    func makeController(
        known: [MultichainAsset],
        isTransferSupported: @escaping (MultichainAsset) -> Bool = { _ in true },
        onRequest: @escaping (String) -> Void = { _ in }
    ) -> EvmSendAssetProbeController {
        EvmSendAssetProbeController(
            resolveAsset: { assetId, _ in
                onRequest(assetId)
                return known.first { $0.asset.assetId == assetId }
            },
            isTransferSupported: isTransferSupported
        )
    }

    func makeTransfer(
        asset: Deeplink.EvmTransferData.Asset,
        chain: MultichainChain?
    ) -> Deeplink.EvmTransferData {
        Deeplink.EvmTransferData(
            recipient: recipient,
            asset: asset,
            chain: chain,
            amount: BigUInt(1)
        )
    }

    func makeState(chains: [MultichainChain]) -> MultichainWalletState {
        MultichainWalletState(
            walletId: "wallet",
            addresses: chains.map { MultichainWalletAddress(chain: $0, address: "address-\($0.rawValue)") }
        )
    }

    func makeAsset(assetId: String) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "Token",
                symbol: "TKN",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: .zero,
            marketCap: [:]
        )
    }
}
