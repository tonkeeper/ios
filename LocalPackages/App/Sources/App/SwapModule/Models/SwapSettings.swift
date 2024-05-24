import Foundation
import KeeperCore

struct SwapSettings {
  let slippage: Float
  let expertMode: Bool
  
  init(slippage: Float, expertMode: Bool) {
    self.slippage = slippage
    self.expertMode = expertMode
  }
}
