import UIKit
import TKUIKit
import TKCoordinator
import TKCore

public struct WalletCustomizationModule {
  public init() {}
  
  public func customizeWalletModule() -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    CustomizeWalletAssembly.module()
  }
}
