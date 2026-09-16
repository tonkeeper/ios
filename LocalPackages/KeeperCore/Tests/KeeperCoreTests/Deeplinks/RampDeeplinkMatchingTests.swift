@testable import KeeperCore
import XCTest

final class RampDeeplinkMatchingTests: XCTestCase {
    func test_matchLayoutAsset_ton_only() {
        let ton = OnRampLayoutToken(
            symbol: "TON",
            assetId: "",
            address: nil,
            network: "ton",
            networkName: "TON",
            networkImage: "",
            image: "",
            decimals: 9,
            stablecoin: false,
            cashMethods: [],
            cryptoMethods: []
        )
        let asset = RampDeeplinkMatching.matchLayoutAsset(in: [ton], fromToken: "TON", fromNetwork: nil)
        XCTAssertEqual(asset?.symbol, "TON")
    }

    func test_matchLayoutAsset_trx_without_fn() {
        let ton = OnRampLayoutToken(
            symbol: "TON",
            assetId: "ton",
            address: nil,
            network: "native",
            networkName: "TON",
            networkImage: "",
            image: "",
            decimals: 9,
            stablecoin: false,
            cashMethods: [],
            cryptoMethods: []
        )
        let trx = OnRampLayoutToken(
            symbol: "TRX",
            assetId: "trx",
            address: nil,
            network: "trc20",
            networkName: "TRON",
            networkImage: "",
            image: "",
            decimals: 6,
            stablecoin: false,
            cashMethods: [],
            cryptoMethods: []
        )
        let asset = RampDeeplinkMatching.matchLayoutAsset(in: [ton, trx], fromToken: "TRX", fromNetwork: nil)
        XCTAssertEqual(asset?.assetId, "trx")
    }

    func test_matchLayoutAsset_usdt_disambiguate_by_fn() {
        let usdtTon = OnRampLayoutToken(
            symbol: "USDT",
            assetId: "a",
            address: nil,
            network: "ton",
            networkName: "TON",
            networkImage: "",
            image: "",
            decimals: 6,
            stablecoin: true,
            cashMethods: [],
            cryptoMethods: []
        )
        let usdtTron = OnRampLayoutToken(
            symbol: "USDT",
            assetId: "b",
            address: nil,
            network: "trc20",
            networkName: "TRON",
            networkImage: "",
            image: "",
            decimals: 6,
            stablecoin: true,
            cashMethods: [],
            cryptoMethods: []
        )
        let tonMatch = RampDeeplinkMatching.matchLayoutAsset(
            in: [usdtTon, usdtTron],
            fromToken: "USDT",
            fromNetwork: "ton"
        )
        XCTAssertEqual(tonMatch?.network.lowercased(), "ton")

        let tronMatch = RampDeeplinkMatching.matchLayoutAsset(
            in: [usdtTon, usdtTron],
            fromToken: "USDT",
            fromNetwork: "trc20"
        )
        XCTAssertEqual(tronMatch?.network.lowercased(), "trc20")
    }

    func test_matchCryptoMethod_uses_tn() {
        let mTon = OnRampLayoutCryptoMethod(
            symbol: "USDT",
            assetId: "",
            address: nil,
            network: "ton",
            networkName: "TON",
            networkImage: "",
            image: "",
            decimals: 6,
            stablecoin: true,
            fee: nil,
            minAmount: nil,
            providers: []
        )
        let mTron = OnRampLayoutCryptoMethod(
            symbol: "USDT",
            assetId: "",
            address: nil,
            network: "trc20",
            networkName: "TRON",
            networkImage: "",
            image: "",
            decimals: 6,
            stablecoin: true,
            fee: nil,
            minAmount: nil,
            providers: []
        )
        let crypto = RampDeeplinkMatching.matchCryptoMethod(
            in: [mTon, mTron],
            toToken: "USDT",
            toNetwork: "trc20"
        )
        XCTAssertEqual(crypto?.network.lowercased(), "trc20")
    }

    func test_matchCashMethod_by_type() {
        let method = OnRampLayoutCashMethod(
            type: "card",
            name: "Bank card",
            image: "",
            providers: [],
            isP2P: false
        )
        let found = RampDeeplinkMatching.matchCashMethod(in: [method], cashMethod: "card")
        XCTAssertEqual(found?.type, "card")
    }
}
