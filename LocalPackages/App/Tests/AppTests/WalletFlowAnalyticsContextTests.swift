@testable import App
import KeeperCoreComponents
import KeeperCoreSensitive
import TKCore
import XCTest

final class WalletFlowAnalyticsContextTests: XCTestCase {
    func testMnemonicImportModeUsesFeatureFlagAndMnemonicStandard() {
        let disabled = WalletFlowAnalyticsContext(from: .main, multichainEnabled: false)
        let enabled = WalletFlowAnalyticsContext(from: .onboarding, multichainEnabled: true)

        XCTAssertEqual(disabled.from, .main)
        XCTAssertEqual(disabled.walletMode(for: .ton), .single)
        XCTAssertEqual(disabled.walletMode(for: .bip39), .single)
        XCTAssertEqual(disabled.walletMode(for: .bip39soft), .single)
        XCTAssertEqual(enabled.from, .onboarding)
        XCTAssertEqual(enabled.walletMode(for: .ton), .single)
        XCTAssertEqual(enabled.walletMode(for: .bip39), .multi)
        XCTAssertEqual(enabled.walletMode(for: .bip39soft), .multi)
    }

    func testKnownMnemonicModeUsesFeatureFlagAndMnemonicStandard() {
        let tonMnemonic = CoreMnemonic(mnemonicWords: [], type: .ton)
        let bip39Mnemonic = CoreMnemonic(mnemonicWords: [], type: .bip39)
        let bip39SoftMnemonic = CoreMnemonic(mnemonicWords: [], type: .bip39soft)

        XCTAssertEqual(WalletMode(knownMnemonic: tonMnemonic, multichainEnabled: true), .single)
        XCTAssertEqual(WalletMode(knownMnemonic: bip39Mnemonic, multichainEnabled: true), .multi)
        XCTAssertEqual(WalletMode(knownMnemonic: bip39SoftMnemonic, multichainEnabled: true), .multi)
        XCTAssertEqual(WalletMode(knownMnemonic: bip39Mnemonic, multichainEnabled: false), .single)
    }
}
