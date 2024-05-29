import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol SwapSettingsModuleOutput: AnyObject {
  var didUpdateSettings: ((SwapSettings) -> Void)? { get set }
}

protocol SwapSettingsViewModel: AnyObject {
  var settings: SwapSettings { get set }
  func viewDidLoad()
  func onSave(settings: SwapSettings)
}

final class SwapSettingsViewModelImplementation: SwapSettingsViewModel, SwapSettingsModuleOutput {
  var settings: SwapSettings
  
  // MARK: - SwapSettingsModuleOutput
  var didUpdateSettings: ((SwapSettings) -> Void)?
  
  // MARK: - SwapSettingsViewModel
  
  func viewDidLoad() {
    setupControllerBindings()
  }
  
  func onSave(settings: SwapSettings) {
    didUpdateSettings?(settings)
  }
  
  // MARK: - Dependencies
  
  private let swapSettingsController: SwapSettingsController
  
  // MARK: - Init
  init(settings: SwapSettings, swapSettingsController: SwapSettingsController) {
    self.settings = settings
    self.swapSettingsController = swapSettingsController
  }
}

private extension SwapSettingsViewModelImplementation {
  func setupControllerBindings() {
  }
}
