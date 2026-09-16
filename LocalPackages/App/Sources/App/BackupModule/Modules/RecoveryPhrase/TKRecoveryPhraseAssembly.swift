struct TKRecoveryPhraseAssembly {
    private init() {}

    static func module(
        provider: TKRecoveryPhraseDataProvider
    ) -> (
        viewController: TKRecoveryPhraseViewController,
        output: TKRecoveryPhraseModuleOutput
    ) {
        let viewModel = TKRecoveryPhraseViewModelImplementation(provider: provider)
        let viewController = TKRecoveryPhraseViewController(viewModel: viewModel)
        return (viewController, viewModel)
    }
}
