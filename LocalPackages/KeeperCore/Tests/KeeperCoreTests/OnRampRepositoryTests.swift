import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class OnRampRepositoryTests: XCTestCase {
    private var storageDirectory: URL!
    private var repository: OnRampRepository!

    override func setUp() {
        super.setUp()
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        repository = OnRampRepositoryImplementation(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDirectory)
        super.tearDown()
    }

    func test_merchantsCachedForOneWalletAreNotReadBackForAnother() throws {
        let merchants = [
            OnRampMerchantInfo(
                id: "merchant",
                title: "Merchant",
                description: "",
                image: "",
                fee: 0,
                isP2P: false,
                buttons: []
            ),
        ]

        try repository.saveMerchants(merchants, walletId: "wallet-a")

        XCTAssertEqual(try repository.getMerchants(walletId: "wallet-a")?.data, merchants)
        XCTAssertNil(try repository.getMerchants(walletId: "wallet-b"))
        XCTAssertNil(try repository.getMerchants(walletId: nil))
    }

    func test_layoutCachedForOneWalletIsNotReadBackForAnother() throws {
        let layout = OnRampLayout(items: [])

        try repository.saveLayout(layout, flow: "buy", currency: "USD", walletId: "wallet-a")

        XCTAssertEqual(
            try repository.getLayout(flow: "buy", currency: "USD", walletId: "wallet-a")?.data,
            layout
        )
        XCTAssertNil(try repository.getLayout(flow: "buy", currency: "USD", walletId: "wallet-b"))
    }
}
