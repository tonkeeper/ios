import Foundation
import KeeperCore
import BigInt

struct StakingInputModelConvertedItem {
  let amount: BigUInt
  let fractionDigits: Int
  let symbol: String
  let isIconHidden: Bool
}

struct StakingInputInputItem {
  let amount: BigUInt
  let fractionDigits: Int
  let symbol: String?
  let maximumFractionDigits: Int
}

struct StakingInputButtonItem {
  let title: String
  let isEnable: Bool
}

enum StakingInputRemainingItem {
  case lessThanMinDeposit(BigUInt, Int)
  case remaining(BigUInt, Int)
  case insufficient
}

enum StakingInputPoolInfoItem {
  case poolInfo(StackingPoolInfo, isMostProfitable: Bool, profit: BigUInt)
  case cycleInfo(String)
}

protocol StakingInputModel: AnyObject {
  var title: String { get }
  var didUpdateIsMax: ((Bool) -> Void)? { get set }
  var didUpdateConvertedItem: ((StakingInputModelConvertedItem) -> Void)? { get set }
  var didUpdateInputItem: ((StakingInputInputItem) -> Void)? { get set }
  var didUpdateRemainingItem: ((StakingInputRemainingItem) -> Void)? { get set }
  var didUpdateButtonItem: ((StakingInputButtonItem) -> Void)? { get set }
  var didUpdatePoolInfoItem: ((StakingInputPoolInfoItem?) -> Void)? { get set }
  var selectedStackingPoolInfo: StackingPoolInfo? { get }
  
  func start()
  func didEditAmountInput(_ input: String)
  func toggleInputMode()
  func toggleIsMax()
  func setSelectedStackingPool(_ pool: StackingPoolInfo)
  func getPickerSections(completion: @escaping (StakingListModel) -> Void)
}
