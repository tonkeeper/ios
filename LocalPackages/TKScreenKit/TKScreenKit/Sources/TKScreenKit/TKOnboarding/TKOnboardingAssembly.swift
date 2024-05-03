import Foundation

public struct TKOnboardingAssembly {
  private init() {}
  public static func module(model: TKOnboardingModel) -> (viewController: TKOnboardingViewController, output: TKOnboardingModuleOutput) {
    let viewModel = TKOnboardingViewModelImplementation(model: model)
    let viewController = TKOnboardingViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
