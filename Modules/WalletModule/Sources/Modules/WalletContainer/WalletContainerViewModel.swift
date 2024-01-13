import Foundation
import TKUIKit

protocol WalletContainerModuleOutput: AnyObject {
  
}

protocol WalletContainerViewModel: AnyObject {
  var didUpdateModel: ((WalletContainerView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class WalletContainerViewModelImplementation: WalletContainerViewModel, WalletContainerModuleOutput {
  
  // MARK: - WalletContainerModuleOutput
  
  // MARK: - WalletContainerViewModel
  
  var didUpdateModel: ((WalletContainerView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension WalletContainerViewModelImplementation {
  func createModel() -> WalletContainerView.Model {
    let walletButtonModel = WalletContainerWalletButton.Model(
      title: "🙃 Money",
      icon: .init(icon: .TKUIKit.Icons.Size16.chevronDown, position: .right)
    )
    
    let walletButtonAppearance = WalletContainerWalletButton.Appearance(
      backgroundColor: .Tint.color1,
      foregroundColor: .Icon.primary
    )
    
    let settingsButtonModel = TKUIHeaderAccentIconButton.Model(image: .TKUIKit.Icons.Size28.gear)
    
    let topBarViewModel = WalletContainerTopBarView.Model(
      walletButtonModel: walletButtonModel,
      walletButtonAppearance: walletButtonAppearance,
      settingsButtonModel: settingsButtonModel
    )
    
    return WalletContainerView.Model(
      topBarViewModel: topBarViewModel
    )
  }
}
