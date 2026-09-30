import EventSource
import Foundation
import HTTPTypes
import MultichainAPI
import OpenAPIRuntime
import StreamURLSessionTransport
import SwapAPI
import TKPerpsAPI
import TonAPI
import TonConnectAPI
import TonStreamingAPIV2

public final class APIAssembly {
    let configurationAssembly: ConfigurationAssembly
    /// Exchange operations carry it as the typed `F` header they declare, so the swap client
    /// leaves it to the API layer instead of stamping every request from a middleware.
    let firebaseUserIdProvider: @Sendable () -> String?

    /// One session per timeout profile, shared by every client on it. Not `lazy`: these are read
    /// from concurrent tasks and `lazy var` is not atomic, so a first access from two threads would
    /// build two sessions and release one from under a live task.
    private let urlSession: URLSession

    /// An SSE connection idles between events, so minutes rather than the ordinary 60 s.
    /// `timeoutIntervalForResource` keeps its 7-day default: it cannot be overridden per request.
    private let streamingUrlSession: URLSession

    /// SSE, so the body has to be consumed incrementally.
    private let streamingTransport: StreamURLSessionTransport

    private let apiTransport: URLSessionTransport

    init(
        configurationAssembly: ConfigurationAssembly,
        firebaseUserIdProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        self.configurationAssembly = configurationAssembly
        // An empty id is not something the backend can key on, and the header this replaced
        // never carried one.
        self.firebaseUserIdProvider = { firebaseUserIdProvider()?.nilIfEmpty }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        let urlSession = URLSession(configuration: configuration)

        let streamingConfiguration = URLSessionConfiguration.default
        streamingConfiguration.timeoutIntervalForRequest = 300
        let streamingUrlSession = URLSession(configuration: streamingConfiguration)

        self.urlSession = urlSession
        self.streamingUrlSession = streamingUrlSession
        apiTransport = URLSessionTransport(urlSession: urlSession)
        streamingTransport = StreamURLSessionTransport(urlSession: streamingUrlSession)
    }

    // MARK: - Internal

    var apiProvider: APIProvider {
        APIProvider { [api, testnetAPI] network in
            switch network {
            case .mainnet: return api
            case .testnet: return testnetAPI
            }
        }
    }

    lazy var api: API = API(
        hostProvider: tonApiHostProvider,
        urlSession: urlSession,
        configuration: configurationAssembly.configuration,
        requestCreationQueue: apiRequestCreationQueue
    )

    lazy var testnetAPI: API = API(
        hostProvider: testnetTonApiHostProvider,
        urlSession: urlSession,
        configuration: configurationAssembly.configuration,
        requestCreationQueue: apiRequestCreationQueue
    )

    public lazy var pushNotificationsAPI: PushNotificationsAPI = PushNotificationsAPI(urlSession: .shared)

    private lazy var apiRequestCreationQueue = DispatchQueue(label: "APIRequestCreationQueue")

    private var tonApiHostProvider: APIHostProvider {
        MainnetAPIHostProvider(configuration: configurationAssembly.configuration)
    }

    private var testnetTonApiHostProvider: APIHostProvider {
        TestnetAPIHostProvider(configuration: configurationAssembly.configuration)
    }

    var streamingAPIV2Provider: StreamingAPIV2Provider {
        StreamingAPIV2Provider { [streamingAPIV2Task, testnetStreamingAPIV2Task] network in
            switch network {
            case .mainnet: return await streamingAPIV2Task.value
            case .testnet: return await testnetStreamingAPIV2Task.value
            }
        }
    }

    private func makeStreamingAPIV2(for network: Network) async -> TonStreamingAPIV2.StreamingAPI? {
        let configuration = configurationAssembly.configuration
        guard let endpoint = await configuration.tonAPISSEEndpointV2(network: network),
              !endpoint.isEmpty,
              let host = URL(string: endpoint)
        else {
            return nil
        }

        return TonStreamingAPIV2.StreamingAPI(
            urlSession: streamingUrlSession,
            hostProvider: {
                host
            },
            tokenProvider: {
                await configuration.tonApiV2Key
            }
        )
    }

    private lazy var streamingAPIV2Task: Task<TonStreamingAPIV2.StreamingAPI?, Never> = Task {
        await makeStreamingAPIV2(for: .mainnet)
    }

    private lazy var testnetStreamingAPIV2Task: Task<TonStreamingAPIV2.StreamingAPI?, Never> = Task {
        await makeStreamingAPIV2(for: .testnet)
    }

    var tonConnectBridgeAPIClientProvider: TonConnectBridgeAPIClientProvider {
        TonConnectBridgeAPIClientProvider(
            tonConnectBridgerAPIClient: { await self.tonConnectAPIClient }
        )
    }

    func swapAPIClient(userAgent: String? = nil) -> SwapAPI.Client {
        let url = configurationAssembly.configuration.value(\.webSwapsUrl, network: .mainnet)
            ?? swapAPIURL
        return SwapAPI.Client(
            serverURL: url,
            transport: apiTransport,
            middlewares: .logged([
                UserAgentHeaderMiddleware(userAgent: userAgent),
            ])
        )
    }

    func multichainAPIClient(userAgent: String? = nil) async -> MultichainAPI.Client {
        MultichainAPI.Client(
            serverURL: await configurationAssembly.configuration.multichainHost(network: .mainnet),
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: apiTransport,
            middlewares: .logged([
                UserAgentHeaderMiddleware(userAgent: userAgent),
                FirebaseUserIdHeaderMiddleware(firebaseUserIdProvider: firebaseUserIdProvider),
            ])
        )
    }

    /// Client for operations that inherit the spec's top-level `deviceJWT` requirement.
    func deviceSessionMultichainAPIClient(
        deviceAuth: DeviceAuthProviding?,
        userAgent: String? = nil
    ) async -> MultichainAPI.Client {
        var middlewares: [any ClientMiddleware] = [
            UserAgentHeaderMiddleware(userAgent: userAgent),
            FirebaseUserIdHeaderMiddleware(firebaseUserIdProvider: firebaseUserIdProvider),
        ]
        // Nothing to authenticate with once the graph that owns the session is gone: the request
        // goes out without the device JWT rather than the process aborting over it.
        if let deviceAuth {
            middlewares.append(DeviceSessionMiddleware(deviceAuth: deviceAuth))
        }
        return MultichainAPI.Client(
            serverURL: await configurationAssembly.configuration.multichainHost(network: .mainnet),
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: apiTransport,
            middlewares: .logged(middlewares)
        )
    }

    /// Client for the operations the spec guards with `security: deviceJWT`. Built per call so
    /// the token is the one the caller resolved, which is also what lets a 401 be retried with
    /// a fresh token instead of replaying a spent `HTTPBody`.
    func deviceAuthMultichainAPIClient(deviceJWT: String, userAgent: String? = nil) async -> MultichainAPI.Client {
        MultichainAPI.Client(
            serverURL: await configurationAssembly.configuration.multichainHost(network: .mainnet),
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: apiTransport,
            middlewares: .logged([
                UserAgentHeaderMiddleware(userAgent: userAgent),
                FirebaseUserIdHeaderMiddleware(
                    firebaseUserIdProvider: firebaseUserIdProvider,
                    operationIDs: [MultichainAPI.Operations.getDeviceBindings.id]
                ),
                BearerTokenMiddleware(token: deviceJWT),
            ])
        )
    }

    /// Client for the operations the spec guards with `deviceJWT` + `walletAuth` + `xWalletId`.
    /// Built per call for the same reason as the device-auth one, and because the wallet token is
    /// only valid for the device token it signs.
    func walletAuthMultichainAPIClient(
        deviceJWT: String?,
        walletId: String,
        walletAuthToken: String?,
        recovery: MultichainWalletAuthDependencies?,
        userAgent: String? = nil
    ) async -> MultichainAPI.Client {
        var middlewares: [any ClientMiddleware] = [
            UserAgentHeaderMiddleware(userAgent: userAgent),
            FirebaseUserIdHeaderMiddleware(firebaseUserIdProvider: firebaseUserIdProvider),
        ]
        // Without a session these operations go out exactly as they did before wallet auth existed,
        // rather than with an empty bearer the backend would have to reject. Recovery is last so
        // it is innermost and can replace the credentials the stack above just applied.
        middlewares.append(
            contentsOf: WalletAuthClientMiddlewares.make(
                deviceJWT: deviceJWT,
                walletId: walletId,
                walletAuthToken: walletAuthToken,
                recovery: recovery
            )
        )
        return MultichainAPI.Client(
            serverURL: await configurationAssembly.configuration.multichainHost(network: .mainnet),
            configuration: OpenAPIRuntime.Configuration(dateTranscoder: MultichainDateTranscoder()),
            transport: apiTransport,
            middlewares: .logged(middlewares)
        )
    }

    func walletAuthPerpsAPIClient(
        hostURL: URL,
        deviceJWT: String?,
        walletId: String,
        walletAuthToken: String?,
        recovery: MultichainWalletAuthDependencies,
        userAgent: String? = nil
    ) throws -> TKPerpsAPI.Client {
        var middlewares: [any ClientMiddleware] = [
            UserAgentHeaderMiddleware(userAgent: userAgent),
            FirebaseUserIdHeaderMiddleware(firebaseUserIdProvider: firebaseUserIdProvider),
        ]
        middlewares.append(
            contentsOf: WalletAuthClientMiddlewares.make(
                deviceJWT: deviceJWT,
                walletId: walletId,
                walletAuthToken: walletAuthToken,
                recovery: recovery
            )
        )
        return try TKPerpsAPI.Client(
            hostURL: hostURL,
            urlSession: urlSession,
            middlewares: middlewares
        )
    }

    private actor TonConnectAPIClientWrapper {
        var _tonConnectAPIClient: TonConnectAPI.Client?
        func setApiClient(tonConnectAPIClient: TonConnectAPI.Client) {
            self._tonConnectAPIClient = tonConnectAPIClient
        }
    }

    private let tonConnectAPIClientWrapper = TonConnectAPIClientWrapper()
    var tonConnectAPIClient: TonConnectAPI.Client {
        get async {
            if let tonConnectAPIClient = await tonConnectAPIClientWrapper._tonConnectAPIClient {
                return tonConnectAPIClient
            }
            let tonConnectBridge = await configurationAssembly.configuration.tonConnectBridge
            let tonConnectAPIClient = TonConnectAPI.Client(
                serverURL: (URL(string: tonConnectBridge) ?? tonConnectURL).appendingPathComponent("bridge"),
                transport: streamingTransport,
                middlewares: .logged()
            )
            await tonConnectAPIClientWrapper.setApiClient(tonConnectAPIClient: tonConnectAPIClient)
            return tonConnectAPIClient
        }
    }

    // MARK: - Private

    var tonConnectURL: URL {
        URL(string: "https://bridge.tonapi.io")!
    }

    private var swapAPIURL: URL {
        URL(string: "https://swap.tonkeeper.com")!
    }

    var tonConnectBridgeURL: URL {
        URL(string: "https://bridge.tonapi.io/bridge")!
    }
}

private struct UserAgentHeaderMiddleware: ClientMiddleware {
    let userAgent: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let userAgent else {
            return try await next(request, body, baseURL)
        }

        var request = request
        request.headerFields[.userAgent] = userAgent
        return try await next(request, body, baseURL)
    }
}
