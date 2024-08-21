import Foundation
import TonSwift

public struct NFTsManagementState: Codable, Equatable {
  public enum NFTState: Codable, Equatable {
    case visible
    case hidden
  }
  
  public let nftStates: [Address: NFTState]
}
