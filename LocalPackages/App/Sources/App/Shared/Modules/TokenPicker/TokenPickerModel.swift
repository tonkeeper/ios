import Foundation
import KeeperCore
import TonSwift

struct TokenPickerModelState {
  let tonBalance: ConvertedTonBalance
  let jettonBalances: [ConvertedJettonBalance]
  let selectedToken: Token
  let scrollToSelected: Bool
}

protocol TokenPickerModel: AnyObject {
  var didUpdateState: ((TokenPickerModelState?) -> Void)? { get set }
  
  func getState() -> TokenPickerModelState?
}
