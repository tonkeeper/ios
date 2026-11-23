@testable import App
import Foundation
import KeeperCore
import PerpsModels
import XCTest

@MainActor
final class PerpsDepositBalanceTests: XCTestCase {
    private let source = PerpsDepositSource(
        assetId: PerpsDepositService.targetAsset.assetId,
        symbol: "USDC",
        decimals: 6,
        network: .ethereum
    )

    func testListedAssetKeepsItsBalanceWithoutLoadingMetadata() async throws {
        let listed = MultichainAsset(
            asset: details(assetId: source.assetId.uppercased()),
            price: .init(prices: ["usd": 1], diff24h: [:], diff7d: [:]),
            balance: 2_000_000
        )

        let asset = try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: { [listed] }, loadDetails: {
            XCTFail("A listed asset already has its metadata")
            return nil
        })

        XCTAssertEqual(asset, listed)
    }

    func testUnheldUSDCHasZeroBalanceAndCatalogIcon() async throws {
        let metadata = details()
        let asset = try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: { [] }, loadDetails: { metadata })

        XCTAssertEqual(asset.asset, metadata)
        XCTAssertEqual(asset.balance, .zero)
        XCTAssertEqual(PerpsLiveDeposit.usdPrice(of: asset), 1)
    }

    func testMissingMetadataKeepsConfirmedZeroBalance() async throws {
        let asset = try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: { [] }, loadDetails: { nil })

        XCTAssertEqual(asset.asset.assetId, source.assetId)
        XCTAssertEqual(asset.asset.symbol, source.symbol)
        XCTAssertEqual(asset.asset.decimals, source.decimals)
        XCTAssertEqual(asset.balance, .zero)
    }

    func testUnheldETHKeepsItsOwnSymbolAndDecimals() async throws {
        let eth = PerpsDepositSource(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, network: .ethereum)
        let asset = try await PerpsLiveDeposit.loadListedAsset(eth, loadAssets: { [] }, loadDetails: { nil })

        XCTAssertEqual(asset.asset.assetId, eth.assetId)
        XCTAssertEqual(asset.asset.symbol, "ETH")
        XCTAssertEqual(asset.asset.decimals, 18)
        XCTAssertEqual(asset.balance, .zero)
        XCTAssertNil(PerpsLiveDeposit.usdPrice(of: asset))
    }

    func testFailedListingDoesNotInventZeroBalance() async {
        do {
            _ = try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: {
                throw URLError(.notConnectedToInternet)
            }, loadDetails: {
                XCTFail("Metadata cannot establish the wallet's balance")
                return nil
            })
            XCTFail("Expected the listing failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testCancellationAfterListingSkipsMetadata() async {
        let task = Task {
            try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: {
                withUnsafeCurrentTask { $0?.cancel() }
                return []
            }, loadDetails: {
                XCTFail("A cancelled load must stop before requesting metadata")
                return nil
            })
        }

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCancellationDuringMetadataDoesNotReturnZeroBalance() async {
        let task = Task {
            try await PerpsLiveDeposit.loadListedAsset(source, loadAssets: { [] }, loadDetails: {
                withUnsafeCurrentTask { $0?.cancel() }
                return self.details()
            })
        }

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    private func details(assetId: String? = nil) -> MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: assetId ?? source.assetId,
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            image: "https://example.com/usdc.png"
        )
    }
}
