import Foundation
import TKCore

struct OnboardingRootAssembly {
  private init() {}
  static func module() -> MVVMModule<OnboardingRootViewController, OnboardingRootModuleOutput, Void> {
    let viewModel = OnboardingRootViewModelImplementation()
    let viewController = OnboardingRootViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
