import Foundation

struct OnboardingModuleAssembly {
  private init() {}
  static func module() -> Module<OnboardingViewController, OnboardingModuleOutput, Void> {
    let viewModel = OnboardingViewModelImplementation()
    let viewController = OnboardingViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
