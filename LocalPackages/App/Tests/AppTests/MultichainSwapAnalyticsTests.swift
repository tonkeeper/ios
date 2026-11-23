@testable import App
import Foundation
@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

final class MultichainSwapAnalyticsTests: XCTestCase {
    func test_open_tellsAMultichainWalletFromAWalletOfTheLegacySwap() {
        let spy = AnalyticsServiceSpy()
        let multichainState = MultichainWalletState(
            walletId: "wallet",
            addresses: [.init(chain: .ton, address: "tonwallet")]
        )

        MultichainSwapAnalytics.logging(to: spy, wallet: makeWallet(multichain: .multichain(multichainState))).logOpen()
        MultichainSwapAnalytics.logging(to: spy, wallet: makeWallet(multichain: nil)).logOpen()

        XCTAssertEqual(spy.events.map(\.name), ["swap_open", "swap_open"])
        XCTAssertEqual(spy.events.map { $0.args["wallet_mode"] as? String }, ["multi", "single"])
        XCTAssertEqual(spy.events.map { $0.args["type"] as? String }, ["native", "native"])
    }
}

extension MultichainSwapAnalytics {
    /// Sends the swap's events to `service` alone.
    static func logging(to service: AnalyticsService, wallet: Wallet) -> MultichainSwapAnalytics {
        let coreAssembly = TKCore.CoreAssembly()
        return MultichainSwapAnalytics(
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [service],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            ),
            wallet: wallet,
            utm: .empty
        )
    }
}

private extension MultichainSwapAnalyticsTests {
    func makeWallet(multichain: MultichainWallet?) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}
