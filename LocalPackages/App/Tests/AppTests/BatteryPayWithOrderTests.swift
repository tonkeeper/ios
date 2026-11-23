@testable import App
import AppUI
import XCTest

final class BatteryPayWithOrderTests: XCTestCase {
    private typealias Kind = BatteryPayWithOrder.Kind

    func testUSDTOnTronThenGramThenAppStoreLeadAndTheRestFollowInOrder() {
        let items: [(String, Kind)] = [("usdc", .other), ("ton-usdt", .tonUSDT), ("eth-usdt", .ethereumUSDT), ("gram", .gram), ("bnb", .other), ("tron-usdt", .tronUSDT), ("app", .appStore)]
        let split = BatteryPayWithOrder.split(items, kind: \.1)
        XCTAssertEqual(split.featured.map(\.0), ["tron-usdt", "gram", "app"])
        XCTAssertEqual(split.other.map(\.0), ["usdc", "ton-usdt", "eth-usdt", "bnb"])
    }

    func testUSDTOnEthereumLeadsWithoutUSDTOnTron() {
        let items: [(String, Kind)] = [("bnb", .other), ("ton-usdt", .tonUSDT), ("gram", .gram), ("eth-usdt", .ethereumUSDT), ("app", .appStore)]
        let split = BatteryPayWithOrder.split(items, kind: \.1)
        XCTAssertEqual(split.featured.map(\.0), ["eth-usdt", "gram", "app"])
        XCTAssertEqual(split.other.map(\.0), ["bnb", "ton-usdt"])
    }

    func testUSDTOnTonLeadsWithoutUSDTOnTron() {
        let items: [(String, Kind)] = [("bnb", .other), ("ton-usdt", .tonUSDT), ("app", .appStore)]
        let split = BatteryPayWithOrder.split(items, kind: \.1)
        XCTAssertEqual(split.featured.map(\.0), ["ton-usdt", "app"])
        XCTAssertEqual(split.other.map(\.0), ["bnb"])
    }

    func testWithoutLeadingMethodsEveryMethodStaysInTheList() {
        let items: [(String, Kind)] = [("bnb", .other), ("sol", .other)]
        let split = BatteryPayWithOrder.split(items, kind: \.1)
        XCTAssertEqual(split.featured.map(\.0), ["bnb", "sol"])
        XCTAssertTrue(split.other.isEmpty)
    }

    func testOnlyTheUSDTOnTronAssetIdCountsAsUSDTOnTron() {
        XCTAssertTrue(BatteryPayWithOrder.isTronUSDT(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"))
        XCTAssertFalse(BatteryPayWithOrder.isTronUSDT(assetId: "tron/mainnet/coin"))
        XCTAssertFalse(BatteryPayWithOrder.isTronUSDT(assetId: "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955"))
    }

    func testOnlyTheUSDTOnEthereumAssetIdCountsAsUSDTOnEthereum() {
        XCTAssertTrue(BatteryPayWithOrder.isEthereumUSDT(assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"))
        XCTAssertTrue(BatteryPayWithOrder.isEthereumUSDT(assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"))
        XCTAssertFalse(BatteryPayWithOrder.isEthereumUSDT(assetId: "base/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"))
        XCTAssertFalse(BatteryPayWithOrder.isEthereumUSDT(assetId: "eth/mainnet/erc20/0x1234"))
        XCTAssertFalse(BatteryPayWithOrder.isEthereumUSDT(assetId: "eth/mainnet/coin"))
    }

    func testOtherTokensCaptionNamesThreeAndCountsTheRest() {
        XCTAssertEqual(BatteryPayWithView.otherTokensCaption(symbols: ["ETH", "BNB"]), "ETH, BNB")
        XCTAssertEqual(BatteryPayWithView.otherTokensCaption(symbols: ["ETH", "BNB", "SOL"]), "ETH, BNB, SOL")
        XCTAssertEqual(BatteryPayWithView.otherTokensCaption(symbols: ["ETH", "BNB", "SOL", "USDC", "DAI"]), "ETH, BNB, SOL and 2 more")
        XCTAssertEqual(BatteryPayWithView.otherTokensCaption(symbols: ["USDT", "USDT", "ETH", "USDT", "USDC", "DAI"]), "USDT, ETH, USDC and 1 more")
    }
}
