import Foundation
import TKUIKit

protocol WalletBalanceModuleOutput: AnyObject {
  
}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateModel: ((WalletBalanceView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  // MARK: - WalletBalanceViewModel
  
  var didUpdateModel: ((WalletBalanceView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension WalletBalanceViewModelImplementation {
  func createModel() -> WalletBalanceView.Model {
    
    let balanceViewModel = WalletBalanceHeaderBalanceView.Model(
      balance: "$17,471",
      address: "EQF2…G21Z",
      addressAction: {}
    )
    
    let headerViewModel = WalletBalanceHeaderView.Model(
      balanceViewModel: balanceViewModel,
      buttonsViewModel: createButtonsViewModel()
    )
    
    return WalletBalanceView.Model(
      headerViewModel: headerViewModel
    )
  }
  
  func createButtonsViewModel() -> WalletBalanceHeaderButtonsView.Model {
    WalletBalanceHeaderButtonsView.Model(buttons: [
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.arrowUpOutline, title: "Send"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.arrowDownOutline, title: "Receive"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.qrViewFinderThin, title: "Scan"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.swapHorizontalOutline, title: "Swap"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.usd, title: "Buy or Sell"),
        action: {}
      ),
      WalletBalanceHeaderButtonsView.Model.Button(
        configuration: TKUIIconButton.Model(image: .TKUIKit.Icons.Size28.stakingOutline, title: "Stake"),
        action: {}
      )
    ])
  }
}
