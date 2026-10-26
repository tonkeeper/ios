@testable import KeeperCore
import XCTest

final class AssetIdComponentsSameAssetTests: XCTestCase {
    private let usdt = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    func test_theAddressCaseDoesNotMatter() {
        XCTAssertTrue(AssetIdComponents.isSameAsset(usdt, "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7"))
    }

    func test_aChainAliasNamesTheSameChain() {
        XCTAssertTrue(AssetIdComponents.isSameAsset(
            "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955",
            "bnb/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955"
        ))
        XCTAssertTrue(AssetIdComponents.isSameAsset("tron/mainnet/coin", "trx/mainnet/coin"))
    }

    func test_theTypeLabelDoesNotMatterOnOneChain() {
        XCTAssertTrue(AssetIdComponents.isSameAsset(usdt, "eth/mainnet/token/0xdac17f958d2ee523a2206206994597c13d831ec7"))
    }

    func test_anotherContractChainOrNetworkIsAnotherAsset() {
        XCTAssertFalse(AssetIdComponents.isSameAsset(usdt, "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"))
        XCTAssertFalse(AssetIdComponents.isSameAsset(usdt, "arb/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"))
        XCTAssertFalse(AssetIdComponents.isSameAsset(usdt, "eth/testnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"))
        XCTAssertFalse(AssetIdComponents.isSameAsset(usdt, "eth/mainnet/coin"))
    }

    func test_coinsOfOneChainAreOneAsset() {
        XCTAssertTrue(AssetIdComponents.isSameAsset("eth/mainnet/coin", "ETH/mainnet/coin"))
        XCTAssertFalse(AssetIdComponents.isSameAsset("eth/mainnet/coin", "base/mainnet/coin"))
    }

    func test_idsTheParserCannotReadCompareAsText() {
        XCTAssertTrue(AssetIdComponents.isSameAsset("battery/mainnet", "BATTERY/mainnet"))
        XCTAssertFalse(AssetIdComponents.isSameAsset("battery/mainnet", usdt))
    }
}
