import Foundation
import KeeperCore

struct SwapModel {
  let sellItem: SwapItem
  let buyItem: SwapItem?
  
  init(sellItem: SwapItem,
       buyItem: SwapItem?) {
    self.sellItem = sellItem
    self.buyItem = buyItem
  }
}


