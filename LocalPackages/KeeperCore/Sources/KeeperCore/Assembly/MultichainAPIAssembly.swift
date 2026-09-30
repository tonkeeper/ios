import Foundation

/// What a wallet-scoped multichain call needs beyond the endpoint itself: who is calling, and the
/// credential naming the wallet it may act on.
struct MultichainWalletAuthDependencies {
    let deviceAuth: DeviceAuthProviding
    let walletAuthTokenProvider: WalletAuthTokenProviding
}

final class MultichainAPIAssembly {
    private var _multichainClientAPI: MultichainClientAPI?
    private var _multichainAuthClientAPI: MultichainAuthClientAPI?

    let appInfoProvider: AppInfoProvider
    let apiAssembly: APIAssembly
    /// Resolved lazily: the provider needs `ChainKitService`, whose assembly is built from this
    /// one, so holding it directly would close the graph into a cycle. `nil` once the graph that
    /// vends it is gone — a client built then goes out unauthenticated, as it did before wallet
    /// auth existed, rather than taking the process down.
    let walletAuth: () -> MultichainWalletAuthDependencies?

    init(
        appInfoProvider: AppInfoProvider,
        apiAssembly: APIAssembly,
        walletAuth: @escaping () -> MultichainWalletAuthDependencies?
    ) {
        self.appInfoProvider = appInfoProvider
        self.apiAssembly = apiAssembly
        self.walletAuth = walletAuth
    }

    func multichainAPI() -> MultichainClientAPI {
        if let api = _multichainClientAPI {
            return api
        }
        let api = MultichainClientAPIImplementation(
            multichainAPIClient: { [apiAssembly, appInfoProvider] in
                await apiAssembly.multichainAPIClient(userAgent: appInfoProvider.userAgent)
            },
            deviceScopedAPIClient: { [apiAssembly, appInfoProvider, walletAuth] in
                await apiAssembly.deviceSessionMultichainAPIClient(
                    deviceAuth: walletAuth()?.deviceAuth,
                    userAgent: appInfoProvider.userAgent
                )
            },
            walletScopedAPIClient: { [apiAssembly, appInfoProvider, walletAuth] walletId in
                let dependencies = walletAuth()
                // A wallet the device cannot authenticate for still reaches the endpoint; the
                // backend accepts the credential's absence, so the call is not worth failing here.
                let session = try? await dependencies?.deviceAuth.session()
                let accessToken = session?.accessToken ?? ""
                var walletAuthToken: String?
                if let dependencies {
                    walletAuthToken = await dependencies.walletAuthTokenProvider.token(
                        walletId: walletId,
                        accessToken: accessToken
                    )
                }
                return await apiAssembly.walletAuthMultichainAPIClient(
                    deviceJWT: accessToken,
                    walletId: walletId,
                    walletAuthToken: walletAuthToken,
                    recovery: dependencies,
                    userAgent: appInfoProvider.userAgent
                )
            }
        )
        _multichainClientAPI = api
        return api
    }

    func multichainAuthAPI() -> MultichainAuthClientAPI {
        if let api = _multichainAuthClientAPI {
            return api
        }
        let api = MultichainAuthClientAPIImplementation(
            multichainAPIClient: { [apiAssembly, appInfoProvider] in
                await apiAssembly.multichainAPIClient(userAgent: appInfoProvider.userAgent)
            },
            deviceAuthMultichainAPIClient: { [apiAssembly, appInfoProvider] deviceJWT in
                await apiAssembly.deviceAuthMultichainAPIClient(
                    deviceJWT: deviceJWT,
                    userAgent: appInfoProvider.userAgent
                )
            }
        )
        _multichainAuthClientAPI = api
        return api
    }
}
