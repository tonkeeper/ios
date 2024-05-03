//import SignerCore
//
//struct ShowRecoveryPhraseModuleAssembly {
//  private init() {}
//  static func module(assembly: SignerCore.Assembly, walletKey: WalletKey) -> Module<ShowRecoveryPhraseViewController, ShowRecoveryPhraseModuleOutput, Void> {
//    let viewModel = ShowRecoveryPhraseViewModelImplementation(
//      recoveryPhraseController: assembly.recoveryPhraseController(
//        walletKey: walletKey
//      )
//    )
//    let viewController = ShowRecoveryPhraseViewController(viewModel: viewModel)
//    return Module(view: viewController, output: viewModel, input: Void())
//  }
//}
