@testable import App
import KeeperCore
import XCTest

final class TradeAssetDetailsEarnDestinationTests: XCTestCase {
    func test_stakingAssetKeepsItsOwnDestination() {
        XCTAssertEqual(
            TradeAssetDetailsEarnDestination(isStakingAsset: true, offer: offer),
            .staking
        )
    }

    func test_assetWithAnOfferOpensThatVault() {
        XCTAssertEqual(
            TradeAssetDetailsEarnDestination(isStakingAsset: false, offer: offer),
            .vault(offer)
        )
    }

    func test_assetWithoutAnOfferHasNowhereToGo() {
        XCTAssertEqual(
            TradeAssetDetailsEarnDestination(isStakingAsset: false, offer: nil),
            .none
        )
    }
}

private extension TradeAssetDetailsEarnDestinationTests {
    var offer: EarnAssetOffer {
        EarnAssetOffer(
            assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7",
            network: "mainnet",
            vaultId: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a",
            apy: Decimal(2.58)
        )
    }
}
