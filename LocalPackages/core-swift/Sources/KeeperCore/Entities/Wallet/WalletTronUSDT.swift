import Foundation
import TronSwift

public struct WalletTron: Codable {
    public let publicKey: TronSwift.PublicKey
    public let address: TronSwift.Address
    public let isOn: Bool
}
