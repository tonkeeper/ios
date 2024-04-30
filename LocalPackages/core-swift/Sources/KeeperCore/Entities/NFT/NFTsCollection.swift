import Foundation
import TonSwift

struct NFTsCollection: Codable {
  let nfts: [Address: NFT]
}
