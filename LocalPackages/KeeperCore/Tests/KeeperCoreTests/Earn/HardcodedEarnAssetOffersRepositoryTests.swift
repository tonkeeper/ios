@testable import KeeperCore
import XCTest

final class HardcodedEarnAssetOffersRepositoryTests: XCTestCase {
    func testAnswersEmptyWhileEarnIsOff() async throws {
        let repository = HardcodedEarnAssetOffersRepository(isEarnEnabled: false)

        let offers = try await repository.offers(assetIds: [usdt])

        XCTAssertTrue(offers.isEmpty)
    }

    func testFindsTheOfferBoundToTheAsset() async throws {
        let repository = HardcodedEarnAssetOffersRepository(isEarnEnabled: true)

        let offer = try await repository.offer(assetId: usdt)

        XCTAssertEqual(offer?.network, "mainnet")
        XCTAssertEqual(offer?.vaultId, "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a")
        XCTAssertEqual(offer?.apy, Decimal(2.58))
    }

    func testAssetIdCaseDoesNotHideTheOffer() async throws {
        let repository = HardcodedEarnAssetOffersRepository(isEarnEnabled: true)

        let offer = try await repository.offer(assetId: usdt.uppercased())

        XCTAssertEqual(offer?.vaultId, "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a")
    }

    func testAssetWithoutAVaultHasNoOffer() async throws {
        let repository = HardcodedEarnAssetOffersRepository(isEarnEnabled: true)

        let offer = try await repository.offer(assetId: "eth/mainnet/coin")

        XCTAssertNil(offer)
    }

    func testEveryOfferQuotesTheRateOfItsCarouselCard() {
        for offer in EarnHardcodedData.assetOffers {
            XCTAssertTrue(
                EarnHardcodedData.vaults.contains { $0.network == offer.network && $0.vaultId == offer.vaultId && $0.apy == offer.apy },
                "offer for \(offer.assetId) has no matching vault"
            )
        }
    }
}

private extension HardcodedEarnAssetOffersRepositoryTests {
    var usdt: String {
        "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
    }
}
