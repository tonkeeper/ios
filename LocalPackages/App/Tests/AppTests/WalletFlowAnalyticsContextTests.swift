@testable import App
import KeeperCoreComponents
import KeeperCoreSensitive
import TKCore
import XCTest

final class WalletFlowAnalyticsContextTests: XCTestCase {
    func testMnemonicImportModeUsesMnemonicStandard() {
        let context = WalletFlowAnalyticsContext(from: .onboarding)

        XCTAssertEqual(context.from, .onboarding)
        XCTAssertEqual(context.walletMode(for: .ton), .single)
        XCTAssertEqual(context.walletMode(for: .bip39), .multi)
        XCTAssertEqual(context.walletMode(for: .bip39soft), .multi)
    }

    func testKnownMnemonicModeUsesMnemonicStandard() {
        let tonMnemonic = CoreMnemonic(mnemonicWords: [], type: .ton)
        let bip39Mnemonic = CoreMnemonic(mnemonicWords: [], type: .bip39)
        let bip39SoftMnemonic = CoreMnemonic(mnemonicWords: [], type: .bip39soft)

        XCTAssertEqual(WalletMode(knownMnemonic: tonMnemonic), .single)
        XCTAssertEqual(WalletMode(knownMnemonic: bip39Mnemonic), .multi)
        XCTAssertEqual(WalletMode(knownMnemonic: bip39SoftMnemonic), .multi)
    }
}
