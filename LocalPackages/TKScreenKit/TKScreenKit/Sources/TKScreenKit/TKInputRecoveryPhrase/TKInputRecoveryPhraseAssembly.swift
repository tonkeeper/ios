import Foundation

public struct TKInputRecoveryPhraseAssembly {
  private init() {}
  public static func module(title: String,
                            caption: String,
                            continueButtonTitle: String,
                            validator: TKInputRecoveryPhraseValidator,
                            suggestsProvider: TKInputRecoveryPhraseSuggestsProvider)
  -> (viewController: TKInputRecoveryPhraseViewController, output: TKInputRecoveryPhraseModuleOutput) {
    let viewModel = TKInputRecoveryPhraseViewModelImplementation(
      title: title,
      caption: caption,
      continueButtonTitle: continueButtonTitle,
      validator: validator,
      suggestsProvider: suggestsProvider
    )
    let viewController = TKInputRecoveryPhraseViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
