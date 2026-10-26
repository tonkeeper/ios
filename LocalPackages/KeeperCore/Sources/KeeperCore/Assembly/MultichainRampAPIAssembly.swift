final class MultichainRampAPIAssembly {
    private var _multichainRampAPI: MultichainRampAPI?

    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly
    /// Resolved lazily for the same reason as in `MultichainAPIAssembly`: the device session
    /// belongs to a graph built from the assembly that owns this one.
    private let deviceAuth: () -> DeviceAuthProviding?

    init(
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly,
        deviceAuth: @escaping () -> DeviceAuthProviding?
    ) {
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
        self.deviceAuth = deviceAuth
    }

    func multichainRampAPI() -> MultichainRampAPI {
        if let api = _multichainRampAPI {
            return api
        }
        let api = MultichainRampAPIImplementation(
            swapAPIClient: apiAssembly.swapAPIClient(userAgent: appInfoProvider.userAgent),
            deviceSessionSwapAPIClient: { [apiAssembly, appInfoProvider, deviceAuth] in
                apiAssembly.deviceSessionSwapAPIClient(deviceAuth: deviceAuth(), userAgent: appInfoProvider.userAgent)
            },
            appInfoProvider: appInfoProvider,
            firebaseUserIdProvider: apiAssembly.firebaseUserIdProvider
        )
        _multichainRampAPI = api
        return api
    }
}
