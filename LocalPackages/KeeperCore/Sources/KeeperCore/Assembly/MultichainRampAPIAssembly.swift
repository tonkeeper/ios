final class MultichainRampAPIAssembly {
    private var _multichainRampAPI: MultichainRampAPI?

    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly

    init(
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly
    ) {
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
    }

    func multichainRampAPI() -> MultichainRampAPI {
        if let api = _multichainRampAPI {
            return api
        }
        let api = MultichainRampAPIImplementation(
            swapAPIClient: apiAssembly.swapAPIClient(userAgent: appInfoProvider.userAgent),
            appInfoProvider: appInfoProvider,
            firebaseUserIdProvider: apiAssembly.firebaseUserIdProvider
        )
        _multichainRampAPI = api
        return api
    }
}
