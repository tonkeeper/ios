import Foundation
import TonSwift

public enum NFTManagementItem: Codable, Equatable, Hashable {
  case singleItem(Address)
  case collection(Address)
}

public struct NFTsManagementState: Codable, Equatable {
  public enum NFTState: Codable, Equatable {
    case visible
    case hidden
    case spam
  }
  
  public let nftStates: [NFTManagementItem: NFTState]
}
