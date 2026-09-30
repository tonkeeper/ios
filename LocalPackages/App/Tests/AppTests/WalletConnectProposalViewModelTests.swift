@testable import App
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import UIKit
import XCTest

final class WalletConnectProposalViewModelTests: XCTestCase {
    func testPermissionItemsAlwaysIncludeInfoAndActivity() {
        let permissions = WalletConnectProposalPermissionItem.items(methods: [])

        XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity])
    }

    func testPermissionItemsIncludeTransactionApprovalForTransactionMethods() {
        let transactionMethods: [WalletConnectMethod] = [
            .ethSendTransaction,
            .ethSignTransaction,
            .tronSignTransaction,
            .tonSendMessage,
        ]

        for method in transactionMethods {
            let permissions = WalletConnectProposalPermissionItem.items(methods: [method])

            XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity, .transactionApproval])
        }
    }

    func testPermissionItemsIncludeMessageSignForMessageMethods() {
        let messageMethods: [WalletConnectMethod] = [
            .personalSign,
            .ethSignTypedDataV4,
            .tronSignMessage,
            .tonSignData,
        ]

        for method in messageMethods {
            let permissions = WalletConnectProposalPermissionItem.items(methods: [method])

            XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity, .messageSign])
        }
    }

    func testPermissionItemsIncludeBothMethodGroupsInStableOrder() {
        let permissions = WalletConnectProposalPermissionItem.items(methods: [
            .tonSignData,
            .ethSendTransaction,
        ])

        XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity, .transactionApproval, .messageSign])
    }

    func testPermissionItemsDoNotAddPermissionForSwitchChainOnly() {
        let permissions = WalletConnectProposalPermissionItem.items(methods: [.walletSwitchEthereumChain])

        XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity])
    }

    func testPermissionItemsDoNotAddPermissionForGetCapabilitiesOnly() {
        let permissions = WalletConnectProposalPermissionItem.items(methods: [.walletGetCapabilities])

        XCTAssertEqual(permissions.map(\.permission), [.infoAndActivity])
    }

    @MainActor
    func testApproveDisabledWhenWalletCannotSatisfyProposal() {
        let viewModel = WalletConnectProposalViewModel(
            wallet: makeWallet(),
            content: makeContent(canApprove: false),
            contentProvider: { _ in self.makeContent(canApprove: false) },
            resultPresentationDuration: 1_000_000,
            showErrorToast: { _ in }
        )
        var approveCount = 0
        viewModel.didApprove = { _ in
            approveCount += 1
        }

        XCTAssertFalse(viewModel.canApprove)
        viewModel.approve()
        XCTAssertEqual(approveCount, 0)
    }

    @MainActor
    func testApproveDeliveryFailureAllowsRetry() async {
        let viewModel = makeViewModel()
        var approveCount = 0
        var completeCount = 0

        viewModel.didApprove = { _ in
            approveCount += 1
            throw WalletConnectSessionApprovalError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && approveCount == 1
        }
        XCTAssertEqual(completeCount, 0)
        XCTAssertTrue(viewModel.canApprove)
        XCTAssertFalse(viewModel.canReject)

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && approveCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testRejectDeliveryFailureAllowsRetry() async {
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            throw WalletConnectSessionRejectionError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.reject()

        await waitUntil {
            viewModel.actionBarState == .idle && rejectCount == 1
        }
        XCTAssertEqual(completeCount, 0)
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertTrue(viewModel.canReject)

        viewModel.reject()

        await waitUntil {
            viewModel.actionBarState == .idle && rejectCount == 2
        }
        XCTAssertEqual(completeCount, 0)
    }

    @MainActor
    func testApproveRetryCompletesWhenRetrySucceeds() async {
        let viewModel = makeViewModel()
        var approveCount = 0
        var completeCount = 0

        viewModel.didApprove = { _ in
            approveCount += 1
            if approveCount == 1 {
                throw WalletConnectSessionApprovalError.sdk(message: "network", retryable: true)
            }
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && viewModel.canApprove
        }
        viewModel.approve()

        await waitUntil {
            completeCount == 1
        }
        XCTAssertEqual(approveCount, 2)
    }

    @MainActor
    func testApproveValidationFailureWithRejectDeliveryFailureAllowsRejectRetry() async {
        let viewModel = makeViewModel()
        var approveCount = 0
        var rejectCount = 0
        var completeCount = 0

        viewModel.didApprove = { _ in
            approveCount += 1
            throw WalletConnectSessionApprovalError.rejectionFailed(
                .sdk(message: "network", retryable: true)
            )
        }
        viewModel.didReject = {
            rejectCount += 1
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.approve()

        await waitUntil {
            viewModel.actionBarState == .idle && viewModel.canReject
        }
        XCTAssertEqual(approveCount, 1)
        XCTAssertEqual(completeCount, 0)
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertTrue(viewModel.canReject)

        viewModel.approve()
        XCTAssertEqual(approveCount, 1)

        viewModel.reject()

        await waitUntil {
            completeCount == 1
        }
        XCTAssertEqual(rejectCount, 1)
    }

    @MainActor
    func testWalletPickerListExcludesWalletsWithoutMultichainAddresses() {
        let legacyWallet = makeWallet(id: "legacy", multichain: nil)
        let selectedWallet = makeWallet(
            id: "selected",
            multichain: .multichain(.init(walletId: "selected", addresses: [
                MultichainWalletAddress(chain: .eth, address: "0xabc"),
            ]))
        )
        let unavailableWallet = makeWallet(id: "unavailable", multichain: .unavailable)
        let walletsStore = makeWalletsStore(
            wallets: [
                legacyWallet,
                selectedWallet,
                unavailableWallet,
            ]
        )
        let model = WalletConnectWalletsPickerListModel(
            walletsStore: walletsStore,
            selectedWallet: selectedWallet
        )

        let state = model.getState()

        XCTAssertEqual(state.wallets.map(\.id), [selectedWallet.id])
        XCTAssertEqual(state.selectedWalletIdentifier, selectedWallet.id)
        XCTAssertNil(model.getWallet(id: legacyWallet.id))
        XCTAssertNil(model.getWallet(id: unavailableWallet.id))
        XCTAssertEqual(model.getWallet(id: selectedWallet.id), selectedWallet)
    }

    @MainActor
    func testWalletPickerListUpdatesWhenAddedWalletBecomesMultichain() async {
        let selectedWallet = makeWallet(
            id: "selected",
            multichain: .multichain(.init(walletId: "selected", addresses: [
                MultichainWalletAddress(chain: .eth, address: "0xabc"),
            ]))
        )
        let addedWallet = makeWallet(
            id: "added",
            kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 0x02, count: 32)), .v4R2),
            multichain: nil
        )
        let walletsStore = makeWalletsStore(wallets: [selectedWallet])
        let model = WalletConnectWalletsPickerListModel(
            walletsStore: walletsStore,
            selectedWallet: selectedWallet
        )
        var updatedStates = [WalletsListModelState]()
        model.didUpdateState = { state in
            updatedStates.append(state)
        }

        await walletsStore.addWallets([addedWallet])
        await walletsStore.setWalletMultichain(
            wallet: addedWallet,
            multichain: .multichain(.init(walletId: "added", addresses: [
                MultichainWalletAddress(chain: .eth, address: "0xdef"),
            ]))
        )

        await waitUntil {
            updatedStates.contains { state in
                state.wallets.map(\.id) == [selectedWallet.id, addedWallet.id]
            }
        }

        let updatedState = updatedStates.last { state in
            state.wallets.map(\.id) == [selectedWallet.id, addedWallet.id]
        }
        XCTAssertEqual(updatedState?.selectedWalletIdentifier, selectedWallet.id)
    }

    @MainActor
    func testDisappearedRejectsAndCompletes() async {
        let viewModel = makeViewModel()
        var rejectCount = 0
        var completeCount = 0

        viewModel.didReject = {
            rejectCount += 1
            throw WalletConnectSessionRejectionError.sdk(message: "network", retryable: true)
        }
        viewModel.didComplete = {
            completeCount += 1
        }

        viewModel.disappeared()

        await waitUntil {
            rejectCount == 1 && completeCount == 1
        }
        XCTAssertFalse(viewModel.canApprove)
        XCTAssertFalse(viewModel.canReject)
    }
}

private extension WalletConnectProposalViewModelTests {
    @MainActor
    func makeViewModel(resultPresentationDuration: UInt64 = 1_000_000) -> WalletConnectProposalViewModel {
        WalletConnectProposalViewModel(
            wallet: makeWallet(),
            content: makeContent(),
            contentProvider: { _ in self.makeContent() },
            resultPresentationDuration: resultPresentationDuration,
            showErrorToast: { _ in }
        )
    }

    func makeContent(canApprove: Bool = true) -> WalletConnectProposalContent {
        WalletConnectProposalContent(
            dappName: "dApp",
            dappHost: "example.com",
            dappURL: nil,
            dappIconURL: nil,
            walletTitle: "Wallet",
            walletBalance: nil,
            walletAddress: "0xabc",
            validation: .valid,
            canApprove: canApprove,
            permissions: WalletConnectProposalPermissionItem.items(methods: []),
            chains: []
        )
    }

    func makeWallet(
        id: String = "wallet",
        kind: WalletKind? = nil,
        multichain: MultichainWallet? = .multichain(.init(walletId: "wallet", addresses: []))
    ) -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: kind ?? .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet \(id)",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    func makeWalletsStore(wallets: [Wallet]) -> WalletsStore {
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
        return WalletsStore(
            keeperInfoStore: KeeperInfoStore(keeperInfoRepository: repository)
        )
    }

    @MainActor
    func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !condition() {
            XCTFail("Timed out waiting for condition")
        }
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw Error.noKeeperInfo
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
