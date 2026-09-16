struct TKCheckRecoveryPhraseAssembly {
    private init() {}

    static func module(
        provider: TKCheckRecoveryPhraseProvider
    ) -> (
        viewController: TKCheckRecoveryPhraseViewController,
        output: TKCheckRecoveryPhraseModuleOutput
    ) {
        let viewModel = TKCheckRecoveryPhraseViewModelImplementation(provider: provider)
        let viewController = TKCheckRecoveryPhraseViewController(viewModel: viewModel)
        return (viewController, viewModel)
    }
}
