import UIKit

public struct TKInputRecoveryPhraseAssembly {
  private init() {}
  public static func module(title: String,
                            caption: String,
                            continueButtonTitle: String,
                            pasteButtonTitle: String,
                            validator: TKInputRecoveryPhraseValidator,
                            suggestsProvider: TKInputRecoveryPhraseSuggestsProvider,
                            bannerViewProvider: (() -> UIView)? = nil)
  -> (viewController: TKInputRecoveryPhraseViewController, output: TKInputRecoveryPhraseModuleOutput) {
    let viewModel = TKInputRecoveryPhraseViewModelImplementation(
      title: title,
      caption: caption,
      continueButtonTitle: continueButtonTitle,
      pasteButtonTitle: pasteButtonTitle,
      validator: validator,
      suggestsProvider: suggestsProvider
    )
    let viewController = TKInputRecoveryPhraseViewController(
      viewModel: viewModel,
      bannerViewProvider: bannerViewProvider
    )
    return (viewController, viewModel)
  }
}
