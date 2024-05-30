import UIKit
import TKUIKit

public struct PoolImplementation: Codable {
    public let name: String
    public let description: String
    public let url: String
    public let socials: [String]
    public let implementationType: PoolImplementationType
    
    public var pools: [PoolInfo]
    public var maxPoolApy: Double
}
