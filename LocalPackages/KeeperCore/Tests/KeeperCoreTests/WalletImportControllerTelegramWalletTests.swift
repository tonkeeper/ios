@testable import KeeperCore
import TonSwift
import XCTest

final class WalletImportControllerTelegramWalletTests: XCTestCase {
    func test_loaded_wallet_replaces_ton_only_lookup() async throws {
        let found = try makeModel(tonAmount: 1, isActive: true)
        let loaded = try makeModel(tonAmount: 7, isActive: true)
        let service = ActiveWalletsServiceStub(result: .success([loaded]))

        let wallet = await makeController(service: service).loadTelegramWallet(found, network: .mainnet)

        XCTAssertEqual(wallet.balance.tonBalance.amount, 7)
        XCTAssertEqual(service.requestedAccounts.map(\.revision), [.walletTg])
        XCTAssertEqual(service.requestedAccounts.map(\.address), [found.address])
    }

    func test_failed_load_keeps_ton_only_lookup() async throws {
        let found = try makeModel(tonAmount: 1, isActive: true)
        let service = ActiveWalletsServiceStub(result: .failure(URLError(.notConnectedToInternet)))

        let wallet = await makeController(service: service).loadTelegramWallet(found, network: .mainnet)

        XCTAssertEqual(wallet.balance.tonBalance.amount, 1)
    }

    /// The service reports a failed account as an inactive empty model instead of throwing.
    func test_inactive_load_keeps_ton_only_lookup() async throws {
        let found = try makeModel(tonAmount: 1, isActive: true)
        let service = try ActiveWalletsServiceStub(result: .success([makeModel(tonAmount: 0, isActive: false)]))

        let wallet = await makeController(service: service).loadTelegramWallet(found, network: .mainnet)

        XCTAssertEqual(wallet.balance.tonBalance.amount, 1)
    }
}

private extension WalletImportControllerTelegramWalletTests {
    static let rawAddress = "0:73212ffaac1c4dbb4795cd869b92f0ebe4bfde95cf9f45e2299ba8438ebed6e2"

    func makeController(service: ActiveWalletsServiceStub) -> WalletImportController {
        WalletImportController(activeWalletService: service, currencyService: CurrencyServiceStub())
    }

    func makeModel(tonAmount: Int64, isActive: Bool) throws -> ActiveWalletModel {
        try ActiveWalletModel(
            id: Self.rawAddress,
            revision: .walletTg,
            address: Address.parse(Self.rawAddress),
            isActive: isActive,
            balance: Balance(tonBalance: TonBalance(amount: tonAmount), jettonsBalance: []),
            nfts: [],
            history: .unknown
        )
    }
}

private struct CurrencyServiceStub: CurrencyService {
    func getActiveCurrency() throws -> Currency {
        .USD
    }
}

private final class ActiveWalletsServiceStub: ActiveWalletsService, @unchecked Sendable {
    private let result: Result<[ActiveWalletModel], Error>
    private(set) var requestedAccounts: [(id: String, address: Address, revision: WalletContractVersion)] = []

    init(result: Result<[ActiveWalletModel], Error>) {
        self.result = result
    }

    func loadActiveWallets(
        publicKey: TonSwift.PublicKey,
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        XCTFail("unused")
        return []
    }

    func loadActiveWallets(
        accounts: [(id: String, address: Address, revision: WalletContractVersion)],
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        requestedAccounts = accounts
        return try result.get()
    }
}
