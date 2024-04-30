import Foundation

public struct TKInputRecoveryPhraseAssembly {
  private init() {}
  public static func module(validator: TKInputRecoveryPhraseValidator,
                            suggestsProvider: TKInputRecoveryPhraseSuggestsProvider)
  -> (viewController: TKInputRecoveryPhraseViewController, output: TKInputRecoveryPhraseModuleOutput) {
    let viewModel = TKInputRecoveryPhraseViewModelImplementation(
      validator: validator, 
      suggestsProvider: suggestsProvider
    )
    let viewController = TKInputRecoveryPhraseViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
