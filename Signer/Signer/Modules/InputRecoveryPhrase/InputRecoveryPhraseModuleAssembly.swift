import Foundation

struct InputRecoveryPhraseModuleAssembly {
  private init() {}
  static func module() -> Module<InputRecoveryPhraseViewController, InputRecoveryPhraseModuleOutput, Void> {
    let viewModel = InputRecoveryPhraseViewModelImplementation()
    let viewController = InputRecoveryPhraseViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
