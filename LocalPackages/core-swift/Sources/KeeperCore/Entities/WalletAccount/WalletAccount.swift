import Foundation
import TonAPI
@preconcurrency import TonSwift

public struct WalletAccount: Equatable, Codable, Sendable {
    public let address: Address
    public let name: String?
    public let isScam: Bool
    public let isWallet: Bool
}
