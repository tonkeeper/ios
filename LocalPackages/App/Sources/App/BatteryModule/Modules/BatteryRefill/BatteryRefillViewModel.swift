import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

protocol BatteryRefillModuleOutput: AnyObject {
  
}

protocol BatteryRefillModuleInput: AnyObject {
  
}

protocol BatteryRefillViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BatteryRefillViewModelImplementation: BatteryRefillViewModel, BatteryRefillModuleOutput, BatteryRefillModuleInput {
  
  // MARK: - BatteryRefillViewModel

  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)?
  
  func viewDidLoad() {
    
  }
  
  // MARK: - State

  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  
  // MARK: - Init
  
  init(wallet: Wallet) {
    self.wallet = wallet
  }
}

private extension BatteryRefillViewModelImplementation {

}

