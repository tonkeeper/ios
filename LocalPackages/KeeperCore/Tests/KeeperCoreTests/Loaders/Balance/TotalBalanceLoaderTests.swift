import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class TotalBalanceLoaderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// The portfolio total is what the list renders; the fan-out is what the screens behind it
    /// read. A multichain wallet is asked for both, a legacy one only has the second.
    func test_aMultichainWalletIsAskedThroughBothMechanics() async {
        let spy = MechanicsSpy()
        let legacyWallet = Self.makeWallet(id: "legacy", isMultichain: false)
        let multichainWallet = Self.makeWallet(id: "multichain", isMultichain: true)
        let loader = makeLoader(spy: spy)

        await loader.reloadBalances(
            wallets: [legacyWallet, multichainWallet],
            activeWallet: nil,
            currency: .USD
        )

        XCTAssertEqual(
            Set(spy.walletBalanceCalls.map(\.wallet.id)),
            [legacyWallet.id, multichainWallet.id]
        )
        XCTAssertEqual(spy.portfolioTotalCalls.map(\.id), [multichainWallet.id])
    }

    /// The active wallet keeps the full refresh, battery included; the rest of the list is
    /// lightweight so a sweep cannot overwrite a fresher active battery with cache.
    func test_onlyTheActiveWalletIsAskedForTransferFees() async {
        let spy = MechanicsSpy()
        let activeWallet = Self.makeWallet(id: "active", isMultichain: false)
        let otherWallet = Self.makeWallet(id: "other", isMultichain: false)
        let loader = makeLoader(spy: spy)

        await loader.reloadBalances(
            wallets: [activeWallet, otherWallet],
            activeWallet: activeWallet,
            currency: .USD
        )

        let byWallet = Dictionary(
            uniqueKeysWithValues: spy.walletBalanceCalls.map { ($0.wallet.id, $0.includingTransferFees) }
        )
        XCTAssertEqual(byWallet[activeWallet.id], true)
        XCTAssertEqual(byWallet[otherWallet.id], false)
    }

    func test_theSweepPausesBetweenChunksRatherThanArrivingAsOneBurst() async {
        let spy = MechanicsSpy()
        let sleeper = SleeperSpy()
        let wallets = (0 ..< 5).map { Self.makeWallet(id: "wallet-\($0)", isMultichain: false) }
        let loader = makeLoader(spy: spy, sleeper: sleeper)

        await loader.reloadBalances(wallets: wallets, activeWallet: nil, currency: .USD)

        XCTAssertEqual(spy.walletBalanceCalls.count, 5)
        XCTAssertEqual(sleeper.delays, [0.5, 0.5], "three chunks of two are separated by two pauses")
    }

    func test_aCancelledSweepStopsBeforeTheChunksItHasNotReached() async {
        let spy = MechanicsSpy()
        let sleeper = SleeperSpy()
        sleeper.throwsCancellation = true
        let wallets = (0 ..< 5).map { Self.makeWallet(id: "wallet-\($0)", isMultichain: false) }
        let loader = makeLoader(spy: spy, sleeper: sleeper)

        await loader.reloadBalances(wallets: wallets, activeWallet: nil, currency: .USD)

        XCTAssertEqual(
            spy.walletBalanceCalls.count,
            2,
            "the pause after the first chunk answered with cancellation"
        )
    }

    func test_aWalletAnsweredForInsideTheWindowIsNotAskedAgain() async {
        let spy = MechanicsSpy()
        let wallet = Self.makeWallet(id: "legacy", isMultichain: false)
        let balanceStore = Self.makeBalanceStore()
        await balanceStore.setBalanceState(
            .current(Self.balance(date: now.addingTimeInterval(-30))),
            wallet: wallet
        )
        let loader = makeLoader(spy: spy, balanceStore: balanceStore)

        await loader.reloadBalances(wallets: [wallet], activeWallet: nil, currency: .USD)

        XCTAssertTrue(spy.walletBalanceCalls.isEmpty)
    }

    private func makeLoader(
        spy: MechanicsSpy,
        sleeper: SleeperSpy = SleeperSpy(),
        balanceStore: BalanceStore? = nil
    ) -> TotalBalanceLoaderImplementation {
        TotalBalanceLoaderImplementation(
            balanceStore: balanceStore ?? Self.makeBalanceStore(),
            multichainPortfolioStore: MultichainPortfolioStore.makeStub(),
            loadPortfolioTotal: { wallet, _, _ in spy.recordPortfolioTotal(wallet) },
            loadWalletBalance: { wallet, _, includingTransferFees in
                spy.recordWalletBalance(wallet, includingTransferFees: includingTransferFees)
            },
            now: { [now] in now },
            sleep: { try await sleeper.sleep($0) }
        )
    }

    private static func makeBalanceStore() -> BalanceStore {
        BalanceStore(
            walletsStore: WalletsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryStub())),
            repository: WalletBalanceRepositoryStub()
        )
    }

    private static func balance(date: Date) -> WalletBalance {
        WalletBalance(
            date: date,
            balance: Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: []),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    }

    private static func makeWallet(id: String, isMultichain: Bool) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        let multichain: MultichainWallet? = isMultichain ? .multichain(
            MultichainWalletState(
                walletId: "\(id)-multichain-wallet-id",
                addresses: [
                    MultichainWalletAddress(chain: .ton, address: "\(id)-ton-address", type: .tonV5R1),
                ]
            )
        ) : nil
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

private final class MechanicsSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var _walletBalanceCalls = [(wallet: Wallet, includingTransferFees: Bool)]()
    private var _portfolioTotalCalls = [Wallet]()

    var walletBalanceCalls: [(wallet: Wallet, includingTransferFees: Bool)] {
        lock.withLock { _walletBalanceCalls }
    }

    var portfolioTotalCalls: [Wallet] {
        lock.withLock { _portfolioTotalCalls }
    }

    func recordWalletBalance(_ wallet: Wallet, includingTransferFees: Bool) {
        lock.withLock {
            _walletBalanceCalls.append((wallet, includingTransferFees))
        }
    }

    func recordPortfolioTotal(_ wallet: Wallet) {
        lock.withLock { _portfolioTotalCalls.append(wallet) }
    }
}

private final class SleeperSpy: @unchecked Sendable {
    var throwsCancellation = false

    private let lock = NSLock()
    private var _delays = [TimeInterval]()

    var delays: [TimeInterval] {
        lock.withLock { _delays }
    }

    func sleep(_ delay: TimeInterval) async throws {
        lock.withLock { _delays.append(delay) }
        if throwsCancellation {
            throw CancellationError()
        }
    }
}

private struct KeeperInfoRepositoryStub: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw TotalBalanceLoaderTestError.noKeeperInfo
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

private struct WalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> WalletBalance {
        throw TotalBalanceLoaderTestError.noBalance
    }
}

private enum TotalBalanceLoaderTestError: Error {
    case noKeeperInfo
    case noBalance
}
