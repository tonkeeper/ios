import Foundation

final class OnRampAPIAssembly {
    private var _onRampAPI: OnRampAPI?

    let configurationAssembly: ConfigurationAssembly
    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly

    init(
        configurationAssembly: ConfigurationAssembly,
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly
    ) {
        self.configurationAssembly = configurationAssembly
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
    }

    func onRampAPI() -> OnRampAPI {
        if let api = _onRampAPI {
            return api
        }
        let api = OnRampAPIImplementation(
            swapAPIClient: apiAssembly.swapAPIClient(userAgent: appInfoProvider.userAgent),
            appInfoProvider: appInfoProvider
        )
        _onRampAPI = api
        return api
    }
}
