import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class WalletScopedLoaderTests: XCTestCase {
    func test_aBurstOnOneScopeMakesOneRequestAndAnswersEveryCaller() async {
        let probe = LoaderProbe()
        let loader = makeLoader(probe: probe)

        let first = await startReload(loader, probe: probe, scope: .walletId("a"))

        let secondRequest = expectation(description: "no request beside the one in flight")
        secondRequest.isInverted = true
        probe.onStart = { secondRequest.fulfill() }
        let second = Task { await loader.reload(scope: .walletId("a"), force: false) }
        let third = Task { await loader.reload(scope: .walletId("a"), force: false) }
        await fulfillment(of: [secondRequest], timeout: 0.2)

        probe.releaseAll()

        let outputs = await[first.value, second.value, third.value]
        XCTAssertEqual(outputs.map(\.content), [1, 1, 1], "every caller is answered by the one run")
        XCTAssertEqual(probe.startedWalletIds, ["a"])
        XCTAssertEqual(probe.appliedContents, [1])
    }

    func test_forceSupersedesTheRunInFlightAndAnswersItsCallersWithTheNewContent() async {
        let probe = LoaderProbe()
        let loader = makeLoader(probe: probe)

        let first = await startReload(loader, probe: probe, scope: .walletId("a"))

        let secondRequest = expectation(description: "a forced request starts its own run")
        probe.onStart = { secondRequest.fulfill() }
        let second = Task { await loader.reload(scope: .walletId("a"), force: true) }
        await fulfillment(of: [secondRequest], timeout: 1)

        probe.releaseAll()

        let firstOutput = await first.value
        let secondOutput = await second.value
        XCTAssertEqual(firstOutput.content, 2, "the superseded caller is handed the fresher content")
        XCTAssertEqual(secondOutput.content, 2)
        XCTAssertEqual(probe.startedWalletIds, ["a", "a"])
        XCTAssertEqual(probe.appliedContents, [2], "the superseded run must not reach the store")
    }

    func test_scopesDoNotShareARun() async {
        let probe = LoaderProbe()
        let loader = makeLoader(probe: probe)

        let first = await startReload(loader, probe: probe, scope: .walletId("a"))
        let second = await startReload(loader, probe: probe, scope: .walletId("b"))

        probe.releaseAll()

        let firstOutput = await first.value
        let secondOutput = await second.value
        XCTAssertEqual(firstOutput.walletId, "a")
        XCTAssertEqual(secondOutput.walletId, "b")
        XCTAssertEqual(probe.startedWalletIds, ["a", "b"])
    }

    /// A wallet with no multichain state is its own scope rather than sharing the active one's.
    func test_aNonMultichainScopeIsKeptApartFromTheOthers() async {
        let probe = LoaderProbe()
        let loader = makeLoader(probe: probe)

        let first = await startReload(loader, probe: probe, scope: .walletId(nil))
        let second = await startReload(loader, probe: probe, scope: .walletId("a"))

        probe.releaseAll()

        let firstOutput = await first.value
        XCTAssertNil(firstOutput.walletId)
        let secondOutput = await second.value
        XCTAssertEqual(secondOutput.walletId, "a")
        XCTAssertEqual(probe.appliedContents.count, 2)
    }

    func test_theActiveWalletScopeResolvesToTheActiveWalletsId() async {
        let probe = LoaderProbe()
        let walletsStore = WalletsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryFake()))
        await walletsStore.addWallets([Self.wallet])
        let loader = makeLoader(probe: probe, walletsStore: walletsStore)

        let reload = await startReload(loader, probe: probe, scope: .activeWallet)
        probe.releaseAll()

        let output = await reload.value
        XCTAssertEqual(output.walletId, Self.multichainWalletId)
        XCTAssertEqual(probe.startedWalletIds, [Self.multichainWalletId])
    }

    private func makeLoader(
        probe: LoaderProbe,
        walletsStore: WalletsStore? = nil
    ) -> WalletScopedLoader<Int> {
        WalletScopedLoader(
            walletsStore: walletsStore ?? WalletsStore(
                keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryFake())
            ),
            fetch: { await probe.fetch(walletId: $0) },
            apply: { probe.apply(walletId: $0, content: $1) }
        )
    }

    private func startReload(
        _ loader: WalletScopedLoader<Int>,
        probe: LoaderProbe,
        scope: WalletScope
    ) async -> Task<WalletScopedLoader<Int>.Output, Never> {
        let started = expectation(description: "request started")
        probe.onStart = { started.fulfill() }
        let task = Task { await loader.reload(scope: scope, force: false) }
        await fulfillment(of: [started], timeout: 1)
        probe.onStart = nil
        return task
    }

    private static let multichainWalletId = "multichain-wallet-id"

    private static let wallet: Wallet = {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: multichainWalletId,
                    addresses: [
                        MultichainWalletAddress(chain: .ton, address: "ton-address", type: .tonV5R1),
                    ]
                )
            )
        )
    }()
}

private final class LoaderProbe: @unchecked Sendable {
    var onStart: (() -> Void)?

    private let lock = NSLock()
    private var gates = [CheckedContinuation<Void, Never>]()
    private var started = [String?]()
    private var applied = [Int]()
    private var contentCounter = 0

    var startedWalletIds: [String?] {
        lock.withLock { started }
    }

    var appliedContents: [Int] {
        lock.withLock { applied }
    }

    func fetch(walletId: String?) async -> Int {
        let content: Int = lock.withLock {
            started.append(walletId)
            contentCounter += 1
            return contentCounter
        }
        onStart?()
        await withCheckedContinuation { continuation in
            lock.withLock { gates.append(continuation) }
        }
        return content
    }

    func apply(walletId _: String?, content: Int) {
        lock.withLock { applied.append(content) }
    }

    func releaseAll() {
        let continuations: [CheckedContinuation<Void, Never>] = lock.withLock {
            let pending = gates
            gates = []
            return pending
        }
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private struct KeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw KeeperInfoRepositoryFakeError.noKeeperInfo
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

private enum KeeperInfoRepositoryFakeError: Error {
    case noKeeperInfo
}
