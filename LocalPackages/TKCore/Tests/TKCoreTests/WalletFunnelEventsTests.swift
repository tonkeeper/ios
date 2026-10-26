import Foundation
@testable import TKCore
@testable import TKServices
import XCTest

final class WalletFunnelEventsTests: XCTestCase {
    func testWalletFlowEventsEncodeRequiredSources() throws {
        let create = try encode(WalletCreateSuccess(walletMode: .multi, backedUp: true, from: .onboarding))
        let menu = try encode(AddWalletMenuView(from: .main))
        let importStarted = try encode(
            WalletImportStarted(walletMode: .multi, walletSource: .mnemonic, from: .onboarding)
        )
        let importError = try encode(
            WalletImportError(
                walletMode: .single,
                walletSource: .watchonly,
                from: .main,
                errorType: nil,
                errorCode: nil,
                errorMessage: "invalid address"
            )
        )
        let backup = try encode(WalletBackupSuccess(walletMode: .single, source: .walletSetupSection))

        XCTAssertEqual(create["from"] as? String, AddWalletSource.onboarding.rawValue)
        XCTAssertEqual(create["backed_up"] as? Bool, true)
        XCTAssertEqual(menu["from"] as? String, AddWalletSource.main.rawValue)
        XCTAssertEqual(importStarted["wallet_mode"] as? String, WalletMode.multi.rawValue)
        XCTAssertEqual(importStarted["wallet_source"] as? String, WalletSource.mnemonic.rawValue)
        XCTAssertEqual(importStarted["from"] as? String, AddWalletSource.onboarding.rawValue)
        XCTAssertEqual(
            try eventName(WalletImportMnemonicAccepted(walletMode: .multi, walletSource: .mnemonic, from: .onboarding)),
            "wallet_import_mnemonic_accepted"
        )
        XCTAssertEqual(
            try eventName(WalletImportSignerScanned(walletMode: .single, walletSource: .signer, from: .main)),
            "wallet_import_signer_scanned"
        )
        XCTAssertEqual(
            try eventName(WalletImportKeystoneScanned(walletMode: .single, walletSource: .keystone, from: .onboarding)),
            "wallet_import_keystone_scanned"
        )
        XCTAssertEqual(
            try eventName(WalletImportLedgerBluetoothConnected(walletMode: .single, walletSource: .ledger, from: .onboarding)),
            "wallet_import_ledger_bluetooth_connected"
        )
        XCTAssertEqual(
            try eventName(WalletImportLedgerAppOpened(walletMode: .single, walletSource: .ledger, from: .main)),
            "wallet_import_ledger_app_opened"
        )
        XCTAssertEqual(importError["wallet_source"] as? String, WalletSource.watchonly.rawValue)
        XCTAssertEqual(importError["from"] as? String, AddWalletSource.main.rawValue)
        XCTAssertEqual(backup["source"] as? String, BackupSource.walletSetupSection.rawValue)
    }

    func testDepositEventsEncodeWalletMode() throws {
        let started = try encode(
            DepositStarted(from: .walletScreen, walletMode: .multi, availableOptions: ["receive_tokens", "buy_with_fiat"])
        )
        let click = try encode(
            DepositOptionClick(from: .jettonScreen, walletMode: .single, addFundsOption: .receiveTokens)
        )
        let provider = try encode(
            DepositContinueToRampProvider(
                from: .walletScreen,
                walletMode: .multi,
                addFundsOption: .buyWithFiat,
                buyAsset: "eth/mainnet/coin",
                sellAsset: "USD",
                paymentMethod: "card",
                providerName: "provider",
                amount: 10,
                txId: "tx"
            )
        )

        XCTAssertEqual(started["eventName"] as? String, "deposit_started")
        XCTAssertEqual(started["wallet_mode"] as? String, WalletMode.multi.rawValue)
        XCTAssertEqual(click["wallet_mode"] as? String, WalletMode.single.rawValue)
        XCTAssertEqual(click["add_funds_option"] as? String, AddFundsOption.receiveTokens.rawValue)
        XCTAssertEqual(provider["wallet_mode"] as? String, WalletMode.multi.rawValue)
        XCTAssertEqual(try eventName(DepositContinueToP2pMarket(from: .walletScreen, walletMode: .multi, addFundsOption: .buyWithFiat)), "deposit_continue_to_p2p_market")
        XCTAssertEqual(
            try eventName(DepositViewReceiveTokens(from: .walletScreen, walletMode: .single, addFundsOption: .receiveTokens, network: .ton)),
            "deposit_view_receive_tokens"
        )
    }

    func testLedgerModelFromDeviceProductName() {
        XCTAssertEqual(LedgerModel(deviceProductName: "Ledger Nano X"), .nanoX)
        XCTAssertEqual(LedgerModel(deviceProductName: "Ledger Stax"), .stax)
        XCTAssertEqual(LedgerModel(deviceProductName: "Ledger Flex"), .flex)
        XCTAssertEqual(LedgerModel(deviceProductName: "Ledger Nano Gen5"), .nanoGen5)
        XCTAssertEqual(LedgerModel(deviceProductName: "Nano X"), .unknown)
    }

    func testLedgerImportEventsEncodeLedgerModelOnlyWhenKnown() throws {
        let connected = try encode(
            WalletImportLedgerBluetoothConnected(walletMode: .single, walletSource: .ledger, from: .main, ledgerModel: .stax)
        )
        let success = try encode(WalletImportSuccess(walletMode: .multi, walletSource: .mnemonic, from: .main))

        XCTAssertEqual(connected["ledger_model"] as? String, LedgerModel.stax.rawValue)
        XCTAssertNil(success["ledger_model"])
    }

    func testOnboardingEventsEncodeTheirEventNames() throws {
        XCTAssertEqual(try eventName(OnboardingViewWelcome()), "onboarding_view_welcome")
        XCTAssertEqual(try eventName(OnboardingPasscodeCreated()), "onboarding_passcode_created")
        XCTAssertEqual(try eventName(OnboardingPasscodeMismatch()), "onboarding_passcode_mismatch")
        XCTAssertEqual(try eventName(OnboardingViewCustomize()), "onboarding_view_customize")
        XCTAssertEqual(try eventName(OnboardingViewNotifications()), "onboarding_view_notifications")
        XCTAssertEqual(try eventName(OnboardingClickCustomizeContinue()), "onboarding_click_customize_continue")
    }
}

private func encode(_ event: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(event)
    let object = try JSONSerialization.jsonObject(with: data)

    return try XCTUnwrap(object as? [String: Any])
}

private func eventName(_ event: some Encodable) throws -> String? {
    try encode(event)["eventName"] as? String
}
