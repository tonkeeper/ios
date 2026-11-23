@testable import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import WalletExtensions
import XCTest

final class WalletTagTests: XCTestCase {
    private let telegramTag = TKTagSwiftUIViewConfig.accentTag(text: "TELEGRAM", accent: .accentBlue)
    private let watchOnlyListTag = TKTagSwiftUIViewConfig.tag(text: TKLocales.WalletTags.watchOnly)

    func test_watchOnlyTelegramWalletShowsTelegramBeforeWatchOnly() {
        let wallet = makeWallet(kind: .Watchonly(watchedAddress, .walletTg))

        XCTAssertEqual(wallet.listTagSwiftUIConfigurations(), [telegramTag, watchOnlyListTag])
        XCTAssertEqual(
            wallet.balanceTagSwiftUIConfigurations(),
            [telegramTag, .accentTag(text: TKLocales.WalletTags.watchOnly, accent: .accentOrange)]
        )
        XCTAssertEqual(wallet.listTagConfigurations().count, 2)
        XCTAssertTrue(wallet.isWalletTg)
    }

    func test_watchOnlyWalletOfUnknownContractShowsWatchOnlyAlone() {
        let wallet = makeWallet(kind: .Watchonly(watchedAddress))

        XCTAssertEqual(wallet.listTagSwiftUIConfigurations(), [watchOnlyListTag])
        XCTAssertEqual(wallet.listTagConfigurations().count, 1)
        XCTAssertFalse(wallet.isWalletTg)
    }

    func test_watchOnlyW5WalletShowsW5BeforeWatchOnly() {
        let wallet = makeWallet(kind: .Watchonly(watchedAddress, .v5R1))

        XCTAssertEqual(
            wallet.listTagSwiftUIConfigurations(),
            [.accentTag(text: "W5", accent: .accentGreen), watchOnlyListTag]
        )
        XCTAssertFalse(wallet.isWalletTg)
    }

    func test_watchOnlyV4WalletShowsWatchOnlyAlone() {
        let wallet = makeWallet(kind: .Watchonly(watchedAddress, .v4R2))

        XCTAssertEqual(wallet.listTagSwiftUIConfigurations(), [watchOnlyListTag])
    }

    func test_regularTelegramWalletShowsTelegramAlone() {
        let wallet = makeWallet(kind: .Regular(publicKey, .walletTg))

        XCTAssertEqual(wallet.listTagSwiftUIConfigurations(), [telegramTag])
    }

    func test_regularW5WalletKeepsItsGreenTag() {
        let wallet = makeWallet(kind: .Regular(publicKey, .v5R1))

        XCTAssertEqual(wallet.listTagSwiftUIConfigurations(), [.accentTag(text: "W5", accent: .accentGreen)])
    }
}

private extension WalletTagTests {
    var publicKey: TonSwift.PublicKey {
        TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
    }

    var watchedAddress: ResolvableAddress {
        .Resolved(Address(workchain: 0, hash: Data(repeating: 1, count: 32)))
    }

    func makeWallet(kind: WalletKind) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}
