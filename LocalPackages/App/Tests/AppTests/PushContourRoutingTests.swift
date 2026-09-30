@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

/// Which of the two push contours owns a wallet. Getting it wrong does not just pick the slower
/// path: the contours have different kill switches, so a wallet routed to a disabled one is left
/// with no subscription at all.
final class PushContourRoutingTests: XCTestCase {
    func test_multichainWallet_usesV2() {
        let wallet = makeWallet(multichain: .multichain(makeState()))

        XCTAssertTrue(wallet.usesMultichainPush())
    }

    func test_walletEnrichmentRuledOutOfMultichain_usesV1() {
        let wallet = makeWallet(multichain: .unavailable)

        XCTAssertFalse(wallet.usesMultichainPush())
    }

    /// A wallet is added before enrichment classifies it, so it takes v1 in the meantime — the
    /// subscription is taken back once v2 confirms it holds the wallet.
    func test_unclassifiedWallet_usesV1() {
        let wallet = makeWallet(multichain: nil)

        XCTAssertFalse(wallet.usesMultichainPush())
    }

    func test_nonRegularWallet_usesV1() {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        let wallet = makeWallet(
            kind: .Signer(publicKey, .v4R2),
            multichain: .multichain(makeState())
        )

        XCTAssertFalse(wallet.usesMultichainPush())
    }

    func test_notificationsOff_cleansV1WithoutWaitingForBinding() {
        let wallet = makeWallet(multichain: .multichain(makeState(syncState: .pending)))

        XCTAssertTrue(
            wallet.needsLegacyPushCleanup(
                isNotificationsOn: false,
                confirmedMultichainPushWalletIds: []
            )
        )
    }

    func test_notificationsOn_keepsV1UntilV2IsConfirmed() {
        let wallet = makeWallet(multichain: .multichain(makeState()))

        XCTAssertFalse(
            wallet.needsLegacyPushCleanup(
                isNotificationsOn: true,
                confirmedMultichainPushWalletIds: []
            )
        )
    }

    /// v2 subscribes by the binding, so a wallet whose sync has not landed cannot be in the
    /// confirmed set no matter what that set holds — v1 has to keep serving it.
    func test_notificationsOn_keepsV1WhileBindingIsPending() {
        let wallet = makeWallet(multichain: .multichain(makeState(syncState: .pending)))

        XCTAssertFalse(
            wallet.needsLegacyPushCleanup(
                isNotificationsOn: true,
                confirmedMultichainPushWalletIds: ["mc-1"]
            )
        )
    }

    /// A binding that ended `.failed` never becomes bound, so dropping v1 would leave the wallet
    /// with no contour at all.
    func test_notificationsOn_keepsV1WhenBindingFailed() {
        let wallet = makeWallet(multichain: .multichain(makeState(syncState: .failed)))

        XCTAssertFalse(
            wallet.needsLegacyPushCleanup(
                isNotificationsOn: true,
                confirmedMultichainPushWalletIds: ["mc-1"]
            )
        )
    }

    func test_notificationsOn_cleansV1AfterV2IsConfirmed() {
        let wallet = makeWallet(multichain: .multichain(makeState()))

        XCTAssertTrue(
            wallet.needsLegacyPushCleanup(
                isNotificationsOn: true,
                confirmedMultichainPushWalletIds: ["mc-1"]
            )
        )
    }
}

private extension PushContourRoutingTests {
    func makeWallet(
        kind: WalletKind? = nil,
        multichain: MultichainWallet?
    ) -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind ?? .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    func makeState(syncState: MultichainWalletSyncState = .synced) -> MultichainWalletState {
        MultichainWalletState(walletId: "mc-1", addresses: [], syncState: syncState)
    }
}
