import Foundation

public struct TKRecoveryPhraseAssembly {
  private init() {}
  public static func module(provider: TKRecoveryPhraseDataProvider)
  -> (viewController: TKRecoveryPhraseViewController,
      output: TKRecoveryPhraseModuleOutput) {
    let viewModel = TKRecoveryPhraseViewModelImplementation(provider: provider)
    let viewController = TKRecoveryPhraseViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
