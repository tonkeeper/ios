@testable import App
import TKUIKit
import UIKit
import XCTest

final class WalletsListSelectionTests: XCTestCase {
    func testWalletIndexPathIsResolvedInsideWalletsSection() {
        let snapshot = makeSnapshot(walletIdentifiers: ["a", "b", "c"], raffleId: "raffle")

        XCTAssertEqual(WalletsListViewController.walletIndexPath(for: "a", in: snapshot), IndexPath(item: 0, section: 1))
        XCTAssertEqual(WalletsListViewController.walletIndexPath(for: "c", in: snapshot), IndexPath(item: 2, section: 1))
    }

    func testWalletIndexPathIsNilForWalletMissingFromSnapshot() {
        let snapshot = makeSnapshot(walletIdentifiers: ["a", "b"], raffleId: nil)

        XCTAssertNil(WalletsListViewController.walletIndexPath(for: "c", in: snapshot))
    }

    func testWalletIndexPathIgnoresRaffleBannerItem() {
        let snapshot = makeSnapshot(walletIdentifiers: ["a"], raffleId: "raffle")
        let bannerIdentifier = WalletsListItem.raffleBannerItem(raffleId: "raffle").identifier

        XCTAssertNil(WalletsListViewController.walletIndexPath(for: bannerIdentifier, in: snapshot))
    }

    private func makeSnapshot(walletIdentifiers: [String], raffleId: String?) -> WalletsListViewController.Snapshot {
        var snapshot = WalletsListViewController.Snapshot()
        if let raffleId {
            let raffleSection = WalletsListSection.raffleBanner(raffleId: raffleId)
            snapshot.appendSections([raffleSection])
            snapshot.appendItems([.raffleBannerItem(raffleId: raffleId)], toSection: raffleSection)
        }
        let walletsSection = WalletsListSection.wallets(
            footerConfiguration: TKListCollectionViewButtonFooterView.Configuration(
                identifier: "footer",
                content: .init(title: .plainString("Add Wallet")),
                action: {}
            )
        )
        snapshot.appendSections([walletsSection])
        snapshot.appendItems(
            walletIdentifiers.map {
                WalletsListItem(identifier: $0, accessories: [], selectAccessories: [], editingAccessories: [])
            },
            toSection: walletsSection
        )
        return snapshot
    }
}
