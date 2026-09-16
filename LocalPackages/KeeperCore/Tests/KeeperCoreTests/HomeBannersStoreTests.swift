import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class HomeBannersStoreTests: XCTestCase {
    private let wallet = HomeBannersStoreTests.makeWallet(id: "wallet", contractVersion: .v5R1)
    private let siblingWallet = HomeBannersStoreTests.makeWallet(
        id: "sibling-wallet",
        contractVersion: .v4R2
    )

    private var storageDirectory: URL!
    private var repository: HomeBannersRepository!
    private var store: HomeBannersStore!

    override func setUp() {
        super.setUp()
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        repository = HomeBannersRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        store = HomeBannersStore(repository: repository)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDirectory)
        super.tearDown()
    }

    func test_dismissedBannerIsScopedToTheWalletThatDismissedIt() async {
        XCTAssertEqual(
            wallet.multichainWalletState?.walletId,
            siblingWallet.multichainWalletState?.walletId
        )

        let banner = makeBanner(id: "banner-1")
        await store.setBanners([banner], forWalletId: wallet.multichainWalletState?.walletId)
        await store.dismissBanner(id: banner.id, walletId: wallet.id)

        XCTAssertTrue(store.visibleBanners(for: wallet).isEmpty)
        XCTAssertEqual(store.visibleBanners(for: siblingWallet).map(\.id), [banner.id])
    }

    /// A wallet returned to must not find its deck grown back from nothing because another seed
    /// was answered for in the meantime.
    func test_anotherSeedsAnswerDoesNotDisplaceThisOne() async {
        let otherSeedWallet = Self.makeWallet(
            id: "other-seed-wallet",
            contractVersion: .v5R1,
            multichainWalletId: "other-multichain-wallet-id"
        )

        let banner = makeBanner(id: "banner-1")
        await store.setBanners([banner], forWalletId: wallet.multichainWalletState?.walletId)
        await store.setBanners([], forWalletId: otherSeedWallet.multichainWalletState?.walletId)

        XCTAssertEqual(store.visibleBanners(for: wallet).map(\.id), [banner.id])
        XCTAssertTrue(store.visibleBanners(for: otherSeedWallet).isEmpty)
    }

    func test_dismissalIsReportedToObservers() async {
        let banner = makeBanner(id: "banner-1")
        await store.setBanners([banner], forWalletId: wallet.multichainWalletState?.walletId)

        let expectation = expectation(description: "didDismissBanner on dismissal")
        store.addObserver(self) { _, event in
            if case .didDismissBanner = event {
                expectation.fulfill()
            }
        }

        await store.dismissBanner(id: banner.id, walletId: wallet.id)

        await fulfillment(of: [expectation], timeout: 1)
    }

    private func makeBanner(id: String) -> HomeBanner {
        HomeBanner(
            id: id,
            title: "Title",
            description: "Description",
            image: nil,
            textColor: nil,
            backgroundColor: nil,
            button: nil
        )
    }

    private static let sharedMultichainWalletId = "shared-multichain-wallet-id"

    private static func makeWallet(
        id: String,
        contractVersion: WalletContractVersion,
        multichainWalletId: String = sharedMultichainWalletId
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, contractVersion)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: multichainWalletId,
                    addresses: [
                        MultichainWalletAddress(
                            chain: .ton,
                            address: "\(id)-ton-address",
                            type: contractVersion == .v5R1 ? .tonV5R1 : .tonV4R2
                        ),
                    ]
                )
            )
        )
    }
}

private enum HomeBannersKeeperInfoTestError: Error {
    case noKeeperInfo
}
