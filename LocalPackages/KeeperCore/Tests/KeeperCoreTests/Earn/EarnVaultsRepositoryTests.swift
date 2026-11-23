@testable import KeeperCore
import TKEarnAPI
import XCTest

final class EarnVaultsRepositoryTests: XCTestCase {
    func testFeaturedVaultsAreTheBackendListInItsOrder() async throws {
        let api = EarnAPIStub(vaults: { _ in
            .success([
                EarnFixtures.vault(
                    symbol: "USDC",
                    protocolName: "Moonwell",
                    apy: 0.0674,
                    network: "base",
                    vaultId: "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca",
                    image: "https://example.com/usdc.png"
                ),
                EarnFixtures.vault(underlyingAssetId: EarnFixtures.usdtAssetId, symbol: "USDT", apy: 0.0258),
            ])
        })
        let repository = makeRepository(api: api)

        let vaults = try await repository.loadFeaturedVaults()

        XCTAssertEqual(vaults, try [
            EarnVault(
                network: "base",
                vaultId: "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca",
                assetSymbol: "USDC",
                protocolName: "Moonwell",
                apy: XCTUnwrap(Decimal(string: "6.74")),
                iconURL: URL(string: "https://example.com/usdc.png")
            ),
            EarnVault(
                network: "mainnet",
                vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                assetSymbol: "USDT",
                protocolName: "Aave",
                apy: XCTUnwrap(Decimal(string: "2.58")),
                iconURL: nil
            ),
        ])
        let requests = await api.vaultsRequests
        XCTAssertEqual(requests, [.init(currencies: ["usd"], underlyingAssetIds: nil)])
    }

    func testDisabledEarnAsksNothing() async throws {
        let api = EarnAPIStub(vaults: { _ in .success([EarnFixtures.vault()]) })
        let repository = makeRepository(api: api, isEnabled: false)

        let vaults = try await repository.loadFeaturedVaults()
        let offers = try await repository.offers(assetIds: [EarnFixtures.usdcAssetId])

        XCTAssertEqual(vaults, [])
        XCTAssertEqual(offers, [:])
        let requests = await api.vaultsRequests
        XCTAssertEqual(requests, [])
    }

    func testOfferIsTheHighestApyVaultOverEachUnderlyingAsset() async throws {
        let api = EarnAPIStub(vaults: { _ in
            .success([
                EarnFixtures.vault(apy: 0.03, vaultId: "0x3333333333333333333333333333333333333333"),
                EarnFixtures.vault(underlyingAssetId: EarnFixtures.usdtAssetId, apy: 0.04, vaultId: "0x2222222222222222222222222222222222222222"),
                EarnFixtures.vault(apy: 0.05, vaultId: "0x1111111111111111111111111111111111111111"),
            ])
        })
        let repository = makeRepository(api: api)

        let offers = try await repository.offers(assetIds: [EarnFixtures.usdcAssetId, EarnFixtures.usdtAssetId])

        XCTAssertEqual(offers, [
            EarnFixtures.usdcAssetId: EarnAssetOffer(
                assetId: EarnFixtures.usdcAssetId,
                network: "mainnet",
                vaultId: "0x1111111111111111111111111111111111111111",
                apy: 5
            ),
            EarnFixtures.usdtAssetId: EarnAssetOffer(
                assetId: EarnFixtures.usdtAssetId,
                network: "mainnet",
                vaultId: "0x2222222222222222222222222222222222222222",
                apy: 4
            ),
        ])
    }

    func testOfferKeepsTheFirstOfVaultsWithEqualApy() async throws {
        let api = EarnAPIStub(vaults: { _ in
            .success([
                EarnFixtures.vault(apy: 0.03, vaultId: "0x1111111111111111111111111111111111111111"),
                EarnFixtures.vault(apy: 0.03, vaultId: "0x2222222222222222222222222222222222222222"),
            ])
        })
        let repository = makeRepository(api: api)

        let offers = try await repository.offers(assetIds: [EarnFixtures.usdcAssetId])

        XCTAssertEqual(offers[EarnFixtures.usdcAssetId]?.vaultId, "0x1111111111111111111111111111111111111111")
    }

    func testOfferKeepsTheAssetIdItWasAskedForWhateverItsCase() async throws {
        let requested = "eth/mainnet/erc20/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        let api = EarnAPIStub(vaults: { _ in .success([EarnFixtures.vault()]) })
        let repository = makeRepository(api: api)

        let offers = try await repository.offers(assetIds: [requested, "ton/mainnet/coin"])

        XCTAssertEqual(Array(offers.keys), [requested])
        XCTAssertEqual(offers[requested]?.assetId, requested)
    }

    func testOffersAreAskedForInBatchesTheBackendAccepts() async throws {
        let assetIds = (0 ..< 45).map { "eth/mainnet/erc20/0x\(String(format: "%040x", $0))" }
        let api = EarnAPIStub()
        let repository = makeRepository(api: api)

        _ = try await repository.offers(assetIds: assetIds + assetIds.prefix(3).map { $0.uppercased() })

        let requested = await api.vaultsRequests.compactMap(\.underlyingAssetIds)
        XCTAssertEqual(requested.map(\.count).sorted(), [5, 20, 20])
        XCTAssertEqual(Set(requested.flatMap { $0 }), Set(assetIds))
    }

    func testAFailedBatchFailsTheLookup() async {
        let api = EarnAPIStub(vaults: { _ in .failure(.badStatus(502, code: nil)) })
        let repository = makeRepository(api: api)

        do {
            _ = try await repository.offers(assetIds: [EarnFixtures.usdcAssetId])
            XCTFail("expected the lookup to fail")
        } catch {}
    }
}

private extension EarnVaultsRepositoryTests {
    func makeRepository(api: EarnAPI, isEnabled: Bool = true) -> EarnVaultsRepositoryImplementation {
        EarnVaultsRepositoryImplementation(api: api, isEnabled: { isEnabled })
    }
}
