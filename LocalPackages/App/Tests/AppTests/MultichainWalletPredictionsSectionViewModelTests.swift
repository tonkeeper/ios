@testable import App
import AppUI
@testable import KeeperCore
import TKUIKit
import TonSwift
import XCTest

@MainActor
final class MultichainWalletPredictionsSectionViewModelTests: XCTestCase {
    private var streams: [AsyncThrowingStream<PredictionsSnapshot, Error>.Continuation] = []

    func test_appearShowsLoadingUntilTheFirstSnapshot() async {
        let viewModel = makeViewModel()

        viewModel.onAppear()
        XCTAssertEqual(viewModel.state, .loading)

        streams.last?.yield(snapshot)
        await waitForState(of: viewModel) { $0 != .loading }

        XCTAssertEqual(viewModel.state, .cards(balance: "$78.00", cards: snapshot.cards))
    }

    func test_failureBeforeAnySnapshotHidesTheSection() async {
        let viewModel = makeViewModel()

        viewModel.onAppear()
        streams.last?.finish(throwing: StubError())
        await waitForState(of: viewModel) { $0 == nil }

        XCTAssertNil(viewModel.state)
    }

    func test_streamEndingBeforeAnySnapshotHidesTheSection() async {
        let viewModel = makeViewModel()

        viewModel.onAppear()
        streams.last?.finish()
        await waitForState(of: viewModel) { $0 == nil }

        XCTAssertNil(viewModel.state)
    }

    func test_refreshGoesThroughLoadingAgain() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        streams.last?.yield(snapshot)
        await waitForState(of: viewModel) { $0 != .loading }

        viewModel.refresh()
        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertEqual(streams.count, 2)

        streams.last?.yield(snapshot)
        await waitForState(of: viewModel) { $0 != .loading }
        XCTAssertEqual(viewModel.state, .cards(balance: "$78.00", cards: snapshot.cards))
    }

    func test_secureModeMasksBalanceAndPositionAmounts() async {
        let appSettingsStore = makeAppSettingsStore()
        let viewModel = makeViewModel(appSettingsStore: appSettingsStore)
        viewModel.onAppear()
        streams.last?.yield(snapshot)
        await waitForState(of: viewModel) { $0 != .loading }

        await withCheckedContinuation { continuation in
            appSettingsStore.toggleIsSecureMode { _ in continuation.resume() }
        }
        await waitForState(of: viewModel) { $0 != .cards(balance: "$78.00", cards: self.snapshot.cards) }

        guard case let .cards(balance, cards) = viewModel.state,
              case let .position(position) = cards.first?.footer
        else {
            return XCTFail("Expected cards with a position, got \(String(describing: viewModel.state))")
        }
        XCTAssertEqual(balance, .secureModeValueShort)
        XCTAssertEqual(position.amount, .secureModeValueShort)
        XCTAssertEqual(position.change, .secureModeValueShort)
        XCTAssertEqual(position.title, "Up")
        XCTAssertEqual(cards.dropFirst().map(\.footer), snapshot.cards.dropFirst().map(\.footer))
    }
}

private extension MultichainWalletPredictionsSectionViewModelTests {
    var snapshot: PredictionsSnapshot {
        PredictionsSnapshot(
            balance: "$78.00",
            cards: [
                PredictionCardViewData(
                    id: "btc",
                    imageSource: .shimmer,
                    title: "BTC",
                    subtitle: .text("To beat"),
                    footer: .position(
                        PredictionPositionViewData(
                            title: "Up",
                            titleColor: .accentGreen,
                            amount: "$12.20",
                            change: "+$2.20",
                            changeColor: .accentGreen
                        )
                    )
                ),
                PredictionCardViewData(
                    id: "eth",
                    imageSource: .shimmer,
                    title: "ETH",
                    subtitle: .text("6 Dec"),
                    footer: .outcomes(yes: "Yes 54%", no: "No 46%")
                ),
            ]
        )
    }

    func makeViewModel(appSettingsStore: AppSettingsStore? = nil) -> MultichainWalletPredictionsSectionViewModel {
        MultichainWalletPredictionsSectionViewModel(
            snapshots: { [unowned self] in
                AsyncThrowingStream { self.streams.append($0) }
            },
            appSettingsStore: appSettingsStore ?? makeAppSettingsStore()
        )
    }

    func makeAppSettingsStore() -> AppSettingsStore {
        AppSettingsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryStub()))
    }

    func waitForState(
        of viewModel: MultichainWalletPredictionsSectionViewModel,
        where isExpected: (PredictionsSectionState?) -> Bool
    ) async {
        for await state in viewModel.$state.values where isExpected(state) {
            return
        }
    }
}

private struct StubError: Error {}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    private var keeperInfo: KeeperInfo

    init() {
        let wallet = Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
        keeperInfo = KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo, hidesDustBalances: false),
            country: .auto
        )
    }

    func getKeeperInfo() throws -> KeeperInfo {
        keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {}
}
