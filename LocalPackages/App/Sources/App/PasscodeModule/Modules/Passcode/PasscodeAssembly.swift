import Foundation
import UIKit

public struct PasscodeAssembly {
  private init() {}
  public static func module(navigationController: UINavigationController, biometryProvider: PasscodeInputBiometryProvider)
  -> (viewController: PasscodeViewController, output: PasscodeModuleOutput) {
    let viewModel = PasscodeViewModelImplementation(biometryProvider: biometryProvider)
    let viewController = PasscodeViewController(viewModel: viewModel, passcodeNavigationController: navigationController)
    return (viewController, viewModel)
  }
}
