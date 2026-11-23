@testable import KeeperCore
import TonSwift
import XCTest

final class WalletNFTStoreSaveTests: XCTestCase {
    func testUnchangedNFTsAreSavedOnce() async throws {
        let nft = try makeNFT(index: 0)
        let service = AccountNFTServiceStub(results: [.success([nft]), .success([nft])])
        let repository = WalletNFTsRepositorySpy()
        let store = makeStore(service: service, repository: repository)

        await store.loadNFTs()
        await store.loadNFTs()

        XCTAssertEqual(repository.savedNFTs.map(\.all), [[nft]])
    }

    func testChangedNFTsAreSavedAgain() async throws {
        let first = try makeNFT(index: 0)
        let second = try makeNFT(index: 1)
        let service = AccountNFTServiceStub(results: [.success([first]), .success([first, second])])
        let repository = WalletNFTsRepositorySpy()
        let store = makeStore(service: service, repository: repository)

        await store.loadNFTs()
        await store.loadNFTs()

        XCTAssertEqual(repository.savedNFTs.map(\.all), [[first], [first, second]])
    }

    func testFailedSaveIsRetriedOnNextLoad() async throws {
        let nft = try makeNFT(index: 0)
        let service = AccountNFTServiceStub(results: [.success([nft]), .success([nft])])
        let repository = WalletNFTsRepositorySpy()
        repository.failsNextSave = true
        let store = makeStore(service: service, repository: repository)

        await store.loadNFTs()
        await store.loadNFTs()

        XCTAssertEqual(repository.savedNFTs.map(\.all), [[nft]])
    }

    func testFailedLoadIsNotSaved() async throws {
        let nft = try makeNFT(index: 0)
        let service = AccountNFTServiceStub(results: [.success([nft]), .failure(URLError(.notConnectedToInternet))])
        let repository = WalletNFTsRepositorySpy()
        let store = makeStore(service: service, repository: repository)

        await store.loadNFTs()
        let nfts = await store.loadNFTs()

        XCTAssertEqual(repository.savedNFTs.map(\.all), [[nft]])
        XCTAssertEqual(nfts.all, [nft])
    }
}

private extension WalletNFTStoreSaveTests {
    func makeStore(service: AccountNFTService, repository: WalletNFTsRepository) -> WalletNFTStore {
        let wallet = makeWallet()
        return WalletNFTStore(
            wallet: wallet,
            repository: repository,
            nftManagementStore: WalletNFTsManagementStore(
                wallet: wallet,
                accountNFTsManagementRepository: AccountNFTsManagementRepositoryStub()
            ),
            nftsService: service
        )
    }

    func makeNFT(index: Int) throws -> NFT {
        try NFT(nftItem: .init(
            address: "0:" + String(repeating: String(index), count: 64),
            index: Int64(index),
            verified: false,
            metadata: .init(additionalProperties: .init()),
            approvedBy: .init(value1: [.getgems]),
            trust: .none
        ))
    }

    func makeWallet() -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "nft-store-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class AccountNFTServiceStub: AccountNFTService, @unchecked Sendable {
    private var results: [Result<[NFT], Error>]

    init(results: [Result<[NFT], Error>]) {
        self.results = results
    }

    func loadAccountNFTs(
        wallet: Wallet,
        collectionAddress: Address?,
        limit: Int?,
        offset: Int?,
        isIndirectOwnership: Bool
    ) async throws -> [NFT] {
        try results.removeFirst().get()
    }
}

private final class WalletNFTsRepositorySpy: WalletNFTsRepository, @unchecked Sendable {
    private(set) var savedNFTs = [WalletNFTs]()
    var failsNextSave = false

    func get(wallet: Wallet) -> WalletNFTs {
        .empty
    }

    func save(nfts: WalletNFTs, wallet: Wallet) throws {
        if failsNextSave {
            failsNextSave = false
            throw CocoaError(.fileWriteOutOfSpace)
        }
        savedNFTs.append(nfts)
    }
}

private struct AccountNFTsManagementRepositoryStub: AccountNFTsManagementRepository {
    func getState(wallet: Wallet) -> NFTsManagementState {
        NFTsManagementState(nftStates: [:])
    }

    func setState(_ state: NFTsManagementState, wallet: Wallet) throws {}
}
