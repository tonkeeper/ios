@testable import App
@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

@MainActor
final class WalletMigrationViewModelTests: XCTestCase {
    func test_failedReloadKeepsLoadedListAndSelection() async throws {
        let wallet = makeWallet()
        let loaded = try makeValue(wallet: wallet, fiatBalance: 1)
        let service = WalletMigrationServiceMock(handlers: [
            { _, _ in [loaded] },
            { _, _ in throw TestError.offline },
        ])
        let (viewModel, walletsStore) = makeViewModel(wallets: [wallet], service: service)

        await viewModel.start()
        let selectedWalletID = viewModel.selectedWalletId

        walletsStore.sendEvent(.didUpdateWalletMetaData(wallet: wallet))
        await waitUntil {
            await service.invocationCount == 2
        }
        await Task.yield()

        guard case .wallets = viewModel.state else {
            return XCTFail("Expected the loaded list to remain visible")
        }
        XCTAssertEqual(viewModel.selectedWalletId, selectedWalletID)
        XCTAssertTrue(viewModel.isContinueEnabled)
    }

    func test_staleFinalFromCancelledReloadIsIgnored() async throws {
        let wallet = makeWallet()
        let stale = try makeValue(wallet: wallet, fiatBalance: 99)
        let current = try makeValue(wallet: wallet, fiatBalance: 2, nftCount: 1)
        let gate = AsyncGate()
        let service = WalletMigrationServiceMock(handlers: [
            { _, _ in
                await gate.wait()
                return [stale]
            },
            { _, _ in
                [current]
            },
        ])
        let (viewModel, walletsStore) = makeViewModel(wallets: [wallet], service: service)

        let startTask = Task {
            await viewModel.start()
        }
        await waitUntil {
            await service.invocationCount == 1
        }

        walletsStore.sendEvent(.didUpdateWalletMetaData(wallet: wallet))
        await waitUntil {
            !viewModel.items.isEmpty
        }
        let currentSubtitle = try XCTUnwrap(viewModel.items.first?.subtitle)

        await gate.open()
        await startTask.value
        await Task.yield()

        XCTAssertEqual(viewModel.items.first?.subtitle, currentSubtitle)
    }

    func test_loadKeepsSkeletonUntilFinalValues() async throws {
        let wallet = makeWallet()
        let loaded = try makeValue(wallet: wallet, fiatBalance: 1)
        let gate = AsyncGate()
        let service = WalletMigrationServiceMock(handlers: [
            { _, _ in
                await gate.wait()
                return [loaded]
            },
        ])
        let (viewModel, _) = makeViewModel(wallets: [wallet], service: service)

        let startTask = Task {
            await viewModel.start()
        }
        await waitUntil {
            await service.invocationCount == 1
        }

        guard case .loading = viewModel.state else {
            return XCTFail("Expected the skeleton to stay until the service returns")
        }
        XCTAssertNil(viewModel.selectedWalletId)

        await gate.open()
        await startTask.value

        guard case .wallets = viewModel.state else {
            return XCTFail("Expected the final values to show the list")
        }
        XCTAssertEqual(viewModel.selectedWalletId, wallet.id)
    }

    func test_loadedItemsSortedByFiatBalanceDescending() async throws {
        let first = makeWallet(id: "first", publicKeySeed: 1)
        let second = makeWallet(id: "second", publicKeySeed: 2)
        let third = makeWallet(id: "third", publicKeySeed: 3)
        let firstValue = try makeValue(wallet: first, fiatBalance: 5)
        let secondValue = try makeValue(wallet: second, fiatBalance: 100)
        let thirdValue = try makeValue(wallet: third, fiatBalance: 40)
        let service = WalletMigrationServiceMock(handlers: [
            { _, _ in
                [firstValue, secondValue, thirdValue]
            },
        ])
        let (viewModel, _) = makeViewModel(wallets: [first, second, third], service: service)

        await viewModel.start()

        XCTAssertEqual(viewModel.items.map(\.id), ["second", "third", "first"])
        XCTAssertEqual(viewModel.selectedWalletId, "second")
        XCTAssertTrue(viewModel.isContinueEnabled)
    }

    func test_retryFromFailedAppliesNewCurrentReload() async throws {
        let wallet = makeWallet()
        let loaded = try makeValue(wallet: wallet, fiatBalance: 2)
        let service = WalletMigrationServiceMock(handlers: [
            { _, _ in throw TestError.offline },
            { _, _ in [loaded] },
        ])
        let (viewModel, _) = makeViewModel(wallets: [wallet], service: service)

        await viewModel.start()
        guard case .failed = viewModel.state else {
            return XCTFail("Expected initial failure")
        }

        await viewModel.retry()

        guard case .wallets = viewModel.state else {
            return XCTFail("Expected retry to load wallets")
        }
        XCTAssertEqual(viewModel.selectedWalletId, wallet.id)
        XCTAssertTrue(viewModel.isContinueEnabled)
    }
}

private extension WalletMigrationViewModelTests {
    func makeViewModel(
        wallets: [Wallet],
        service: WalletMigrationService
    ) -> (WalletMigrationViewModel, WalletsStore) {
        let repository = KeeperInfoRepositoryMock(
            keeperInfo: KeeperInfo(
                wallets: wallets,
                currentWallet: wallets[0],
                currency: .defaultCurrency,
                securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
                appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
                country: .auto
            )
        )
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: repository)
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let coreAssembly = CoreAssembly()
        let analyticsProvider = AnalyticsProvider(
            analyticsServices: [],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
        let viewModel = WalletMigrationViewModel(
            walletsStore: walletsStore,
            walletMigrationService: service,
            amountFormatter: KeeperCore.FormattersAssembly().amountFormatter,
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            appSettingsStore: AppSettingsStore(keeperInfoStore: keeperInfoStore),
            analyticsProvider: analyticsProvider
        )
        return (viewModel, walletsStore)
    }

    func makeWallet(id: String = "legacy", publicKeySeed: UInt8 = 1) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: publicKeySeed, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Legacy",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .unavailable
        )
    }

    func makeValue(
        wallet: Wallet,
        fiatBalance: Decimal,
        nftCount: Int = 0
    ) throws -> WalletMigrationWalletValue {
        try WalletMigrationWalletValue(
            account: wallet.tonMigrationAccountId(),
            balance: 1,
            jettonsCount: 0,
            nftCount: nftCount,
            fiatBalance: fiatBalance
        )
    }

    func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !(await condition()) {
            XCTFail("Timed out waiting for condition")
        }
    }
}

private actor WalletMigrationServiceMock: WalletMigrationService {
    typealias Handler = @Sendable (
        [Wallet],
        Currency
    ) async throws -> [WalletMigrationWalletValue]

    private var handlers: [Handler]
    private(set) var invocationCount = 0

    init(handlers: [Handler]) {
        self.handlers = handlers
    }

    func prepareMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        currency: Currency
    ) async throws -> WalletMigrationPrepareResult {
        throw TestError.unsupported
    }

    func prepareTronMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet
    ) async throws -> WalletMigrationTronPrepareResult? {
        throw TestError.unsupported
    }

    func availableBatteryCharges(wallet: Wallet) async -> Int? {
        nil
    }

    func getMigrationWallets(
        wallets: [Wallet],
        currency: Currency
    ) async throws -> [WalletMigrationWalletValue] {
        invocationCount += 1
        guard !handlers.isEmpty else {
            throw TestError.unexpectedInvocation
        }
        let handler = handlers.removeFirst()
        return try await handler(wallets, currency)
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var continuations = [CheckedContinuation<Void, Never>]()

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let continuations = continuations
        self.continuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw TestError.noKeeperInfo
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        keeperInfo = nil
    }
}

private enum TestError: Error {
    case noKeeperInfo
    case offline
    case unexpectedInvocation
    case unsupported
}
