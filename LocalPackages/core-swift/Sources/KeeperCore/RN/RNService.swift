import CoreComponents
import Foundation

public protocol RNService {
    func needToMigrate() async -> Bool
    func setMigrationFinished() async throws
    func getWallets() async throws -> [RNWallet]
    func setWallets(_ wallets: [RNWallet]) async throws
    func getActiveWalletId() async throws -> String?
    func setActiveWalletId(_ activeWalletId: String) async throws
    func getWalletBackupDate(walletId: String) async throws -> Date?
    func setWalletBackupDate(date: Date?, walletId: String) async throws
    func getIsBiometryEnable() async throws -> Bool
    func setIsBiometryEnable(_ isBiometryEnable: Bool) async throws
    func getIsLockscreenEnable() async throws -> Bool
    func setIsLockscreenEnable(_ isLockscreenEnable: Bool) async throws
    func getAppTheme() async throws -> RNAppTheme?
    func setAppTheme(_ appTheme: RNAppTheme?) async throws
    func getCurrency() async throws -> Currency
    func getWalletNotificationsSettings(walletId: String) async throws -> Bool
    func setWalletNotificationsSettings(isOn: Bool, walletId: String) async throws
}

private extension String {
    static let walletsStore = "walletsStore"
    static let appTheme = "app-theme"
    static let setup = "setup"
}
