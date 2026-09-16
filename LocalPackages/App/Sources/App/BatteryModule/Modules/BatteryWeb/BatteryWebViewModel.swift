import Foundation
import KeeperCore
import TKLogging

protocol BatteryWebViewModel: AnyObject {
    var didOpen: ((URL, String) -> Void)? { get set }
    var injectHandler: ((String, URL) -> Void)? { get set }
    var jsInjection: String { get }
    var walletIdentifier: String { get }

    func viewDidLoad()
    func didReceiveMessage(body: Any, pageURL: URL?)
}

final class BatteryWebViewModelImplementation: BatteryWebViewModel {
    var didOpen: ((URL, String) -> Void)?
    var injectHandler: ((String, URL) -> Void)?

    var walletIdentifier: String {
        wallet.id
    }

    /// Only the transport the page expects; no TonConnect surface is exposed to this page.
    var jsInjection: String {
        """
        (() => {
            if (!window.ReactNativeWebView) {
                window.ReactNativeWebView = {
                    postMessage: (message) => {
                        window.webkit.messageHandlers.\(BatteryWebBridge.messageHandlerName).postMessage(String(message));
                    }
                };
            }
        })();
        """
    }

    private let wallet: Wallet
    private let url: URL
    private let title: String
    private let authorizationService: BatteryWebAuthorizationService

    init(
        wallet: Wallet,
        url: URL,
        title: String,
        authorizationService: BatteryWebAuthorizationService
    ) {
        self.wallet = wallet
        self.url = url
        self.title = title
        self.authorizationService = authorizationService
    }

    func viewDidLoad() {
        didOpen?(url, title)
    }

    func didReceiveMessage(body: Any, pageURL: URL?) {
        guard BatteryWebBridge.isTrustedOrigin(pageURL: pageURL, startURL: url) else {
            Log.w("battery web bridge: message rejected: untrusted page", extraInfo: [
                "host": pageURL?.host ?? "",
            ])
            return
        }
        guard let request = BatteryWebBridge.parse(body) else {
            return
        }
        Log.d("battery web bridge: request received", extraInfo: [
            "method": request.method.rawValue,
            "queryId": request.queryId,
        ])

        Task { [weak self, wallet, authorizationService] in
            let authorization: BatteryWebAuthorization
            do {
                authorization = try await authorizationService.authorization(
                    for: wallet,
                    expiredDeviceToken: request.expiredAccessToken
                )
            } catch {
                Log.w("battery web bridge: authorization unavailable", error: error, extraInfo: [
                    "queryId": request.queryId,
                ])
                return
            }
            guard let response = BatteryWebBridge.response(queryId: request.queryId, authorization: authorization) else {
                Log.e("battery web bridge: failed to encode response", extraInfo: ["queryId": request.queryId])
                return
            }
            await self?.sendResponse(response)
        }
    }

    @MainActor
    private func sendResponse(_ response: String) {
        let js = """
        (function() {
            window.dispatchEvent(new MessageEvent('message', {
                data: \(response)
            }));
        })();
        """
        injectHandler?(js, url)
    }
}
