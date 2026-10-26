@testable import App
import KeeperCore
import MoonPay
import XCTest

final class MoonPayAssetResolverTests: XCTestCase {
    private let ethereumNative = MoonPayPlatformAsset(
        caip19: "", code: "eth", network: "ethereum", contractAddress: "0x0000000000000000000000000000000000000000"
    )
    private let usdtEthereum = MoonPayPlatformAsset(
        caip19: "", code: "usdt", network: "ethereum", contractAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    )
    private let usdtBsc = MoonPayPlatformAsset(
        caip19: "", code: "usdt_bsc", network: "binance_smart_chain", contractAddress: "0x55d398326f99059fF775485246999027B3197955"
    )
    private let bnbNative = MoonPayPlatformAsset(caip19: "", code: "bnb_bsc", network: "binance_smart_chain")
    private let ton = MoonPayPlatformAsset(caip19: "", code: "ton", network: "ton")
    private let usdtTon = MoonPayPlatformAsset(
        caip19: "",
        code: "usdt_ton",
        network: "ton",
        contractAddress: "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
    )

    private var catalog: [MoonPayPlatformAsset] {
        [ethereumNative, usdtEthereum, usdtBsc, bnbNative, ton, usdtTon]
    }

    func test_nativeCoin_matchesBySymbolOnItsNetwork() {
        let match = MoonPayAssetResolver.match(details("eth/mainnet/coin", symbol: "ETH"), in: catalog)
        XCTAssertEqual(match?.code, "eth")
    }

    func test_nativeCoin_withDifferentCode_matchesTheOnlyNativeOfTheNetwork() {
        let match = MoonPayAssetResolver.match(details("bsc/mainnet/coin", symbol: "BNB"), in: catalog)
        XCTAssertEqual(match?.code, "bnb_bsc")
    }

    func test_token_matchesByContractIgnoringCase() {
        let match = MoonPayAssetResolver.match(
            details("eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7", symbol: "USDT"),
            in: catalog
        )
        XCTAssertEqual(match?.code, "usdt")
    }

    func test_token_neverFallsBackToTheSameAddressOnAnotherNetwork() {
        let onlyEthereum = [usdtEthereum]
        let match = MoonPayAssetResolver.match(
            details("bsc/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7", symbol: "USDT"),
            in: onlyEthereum
        )
        XCTAssertNil(match)
    }

    func test_tonJetton_matchesByRawAddress() {
        let raw = MoonPayAssetResolver.match(
            details("ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe", symbol: "USDT"),
            in: catalog
        )
        XCTAssertEqual(raw?.code, "usdt_ton")
    }

    func test_unavailableAssets_areSkipped() {
        let off = MoonPayPlatformAsset(caip19: "", code: "eth", network: "ethereum", isAvailable: false)
        XCTAssertNil(MoonPayAssetResolver.match(details("eth/mainnet/coin", symbol: "ETH"), in: [off]))
    }

    func test_unknownAssetId_hasNoMatch() {
        XCTAssertNil(MoonPayAssetResolver.match(details("nonsense", symbol: "X"), in: catalog))
    }

    private func details(_ assetId: String, symbol: String) -> MultichainAssetDetails {
        MultichainAssetDetails(assetId: assetId, name: symbol, symbol: symbol, decimals: 18, image: "")
    }
}
