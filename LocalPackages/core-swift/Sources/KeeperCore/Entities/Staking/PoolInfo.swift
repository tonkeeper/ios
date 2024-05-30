import Foundation
import BigInt

public enum PoolImplementationType: String, Codable {
    case whales = "whales"
    case tf = "tf"
    case liquidTF = "liquidTF"
}

public struct PoolInfo: Codable {
    public let address: String
    public let name: String
    public let implementationType: PoolImplementationType?
    public let apy: Double
    public var isMax: Bool
    public let liquidJettonMaster: String?
    public let minStake: BigUInt
}
