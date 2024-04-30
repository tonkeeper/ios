import Foundation

public struct TKCheckRecoveryPhraseAssembly {
  private init() {}
  public static func module(provider: TKCheckRecoveryPhraseProvider)
  -> (viewController: TKCheckRecoveryPhraseViewController, output: TKCheckRecoveryPhraseModuleOutput) {
    let viewModel = TKCheckRecoveryPhraseViewModelImplementation(
      provider: provider
    )
    let viewController = TKCheckRecoveryPhraseViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
