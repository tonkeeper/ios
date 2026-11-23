import Foundation
@testable import Perps
import XCTest

@MainActor
final class PerpsFundingAssetSheetModelTests: XCTestCase {
    func testRowsAreAvailableWhileCatalogIconsLoadAndUpdateIndividually() async {
        let walletIcon = URL(string: "https://example.com/wallet.png")
        let fastIcon = URL(string: "https://example.com/fast.png")
        let slowIcon = URL(string: "https://example.com/slow.png")
        let rows = [row("wallet", icon: walletIcon), row("fast"), row("slow")]
        let model = PerpsFundingAssetSheetModel(assets: rows)
        XCTAssertEqual(model.assets, rows)

        let slowStarted = expectation(description: "slow icon started")
        let fastUpdated = expectation(description: "fast icon published")
        var finish: CheckedContinuation<URL?, Never>?
        let observation = model.$assets.sink { rows in
            if rows[1].iconURL == fastIcon { fastUpdated.fulfill() }
        }
        let loading = Task {
            await model.loadIcons { id in
                switch id {
                case "slow":
                    return await withCheckedContinuation {
                        finish = $0
                        slowStarted.fulfill()
                    }
                case "fast": return fastIcon
                default:
                    XCTFail("Wallet icons must not trigger a catalog lookup")
                    return nil
                }
            }
        }
        await fulfillment(of: [slowStarted, fastUpdated], timeout: 1)
        observation.cancel()
        XCTAssertEqual(model.assets.map(\.assetId), rows.map(\.assetId))
        XCTAssertEqual(model.assets[0].iconURL, walletIcon)
        XCTAssertEqual(model.assets[1].iconURL, fastIcon)
        XCTAssertNil(model.assets[2].iconURL)
        XCTAssertEqual(model.assets[1].balanceText, "fast balance")

        finish?.resume(returning: slowIcon)
        await loading.value
        XCTAssertEqual(model.assets[2].iconURL, slowIcon)
    }

    func testCancellationDoesNotPublishALateIcon() async {
        let rows = [row("slow")]
        let model = PerpsFundingAssetSheetModel(assets: rows)
        let started = expectation(description: "icon started")
        var finish: CheckedContinuation<URL?, Never>?
        let loading = Task {
            await model.loadIcons { _ in
                await withCheckedContinuation {
                    finish = $0
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 1)
        loading.cancel()
        finish?.resume(returning: URL(string: "https://example.com/late.png"))
        await loading.value
        XCTAssertEqual(model.assets, rows)
    }

    private func row(_ id: String, icon: URL? = nil) -> PerpsFundingAssetRow {
        PerpsFundingAssetRow(assetId: id, symbol: "USDC", network: .ethereum, iconURL: icon, balanceText: "\(id) balance")
    }
}
