import TKFeatureFlags

final class MultichainSwapAPIAssembly {
    private var _multichainSwapAPI: MultichainSwapAPI?

    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly
    private let tkAppSettings: TKAppSettings

    init(
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly,
        tkAppSettings: TKAppSettings
    ) {
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
        self.tkAppSettings = tkAppSettings
    }

    func multichainSwapAPI() -> MultichainSwapAPI {
        if let api = _multichainSwapAPI {
            return api
        }
        let api = MultichainSwapAPIImplementation(
            swapAPIClient: apiAssembly.swapAPIClient(userAgent: appInfoProvider.userAgent),
            firebaseUserIdProvider: apiAssembly.firebaseUserIdProvider,
            isNewUser: { [tkAppSettings] in tkAppSettings.raffleIsNewUser ?? false }
        )
        _multichainSwapAPI = api
        return api
    }
}
