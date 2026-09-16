final class MultichainSwapAPIAssembly {
    private var _multichainSwapAPI: MultichainSwapAPI?

    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly

    init(
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly
    ) {
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
    }

    func multichainSwapAPI() -> MultichainSwapAPI {
        if let api = _multichainSwapAPI {
            return api
        }
        let api = MultichainSwapAPIImplementation(
            swapAPIClient: apiAssembly.swapAPIClient(userAgent: appInfoProvider.userAgent),
            firebaseUserIdProvider: apiAssembly.firebaseUserIdProvider
        )
        _multichainSwapAPI = api
        return api
    }
}
