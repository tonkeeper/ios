import Foundation
import TonSwift

public struct WalletInfo: Codable {
    public struct WalletInfoPlugin: Codable {
        public enum AccountStatus: String, Codable, CaseIterable {
            case nonexist
            case uninit
            case active
            case frozen
            case unknownDefaultOpenApi = "unknown_default_open_api"
        }

        public var address: Address
        public var type: String
        public var status: AccountStatus?
    }

    public var address: Address
    public var isWallet: Bool
    public var balance: Int64
    public var plugins: [WalletInfoPlugin]
    public var lastActivity: Int64
}
