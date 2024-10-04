import Foundation
import TonSwift

public struct NFTsCollection: Codable {
  public let nfts: [Address: NFT]
  
  public init(nfts: [Address : NFT]) {
    self.nfts = nfts
  }
}
