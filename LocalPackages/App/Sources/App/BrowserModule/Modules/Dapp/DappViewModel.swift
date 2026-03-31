import KeeperCore
import TKCore
import TKLogging
import TKUIKit
import UIKit
import WebKit

public protocol DappModuleOutput: AnyObject {
    var didShareDappURL: ((_ dapp: Dapp, _ url: URL) -> Void)? { get set }
}

public protocol DappModuleInput: AnyObject {
    func setLandscapeMode(isEnabled: Bool)
}

protocol DappViewModel: AnyObject {
    var didOpenApp: ((URL?, String?) -> Void)? { get set }
    var injectHandler: ((String) -> Void)? { get set }
    var jsInjection: String? { get }
    var walletIdentifier: String? { get }
    var didUpdateIsLandscapeEnable: (() -> Void)? { get set }
    var isLandscapeEnable: Bool { get }
    var didShareURLSystemShareSheet: ((URL) -> Void)? { get set }
    /// Optional handler to customize WebView (e.g., inject TONWalletKit)
    var webViewCustomizationHandler: ((WKWebView) -> Void)? { get }

    func viewDidLoad()
    func didLoadInitialRequest()
    func didReceiveMessage(body: Any)
    func copyDappURL(url: URL)
    func shareDappURL(url: URL)
}

class DappViewModelImplementation: DappViewModel, DappModuleOutput, DappModuleInput {
    // MARK: - DappModuleOutput

    var didShareDappURL: ((_ dapp: Dapp, _ url: URL) -> Void)?

    // MARK: - DappModuleInput

    func setLandscapeMode(isEnabled: Bool) {
        isLandscapeEnable = isEnabled
    }

    // MARK: - DappViewModel

    var didOpenApp: ((URL?, String?) -> Void)?
    var injectHandler: ((String) -> Void)?
    var didUpdateIsLandscapeEnable: (() -> Void)?
    var didShareURLSystemShareSheet: ((URL) -> Void)?
    var webViewCustomizationHandler: ((WKWebView) -> Void)?
    var isLandscapeEnable: Bool = false {
        didSet {
            didUpdateIsLandscapeEnable?()
        }
    }

    func viewDidLoad() {
        didOpenApp?(dapp.url, dapp.name)
        didUpdateIsLandscapeEnable?()
    }

    var walletIdentifier: String? {
        wallet?.id
    }

    func didLoadInitialRequest() {
        self.reconnectIfNeeded()
    }

    func reconnectIfNeeded() {
        messageHandler.reconnectIfNeeded(dapp: dapp) { [weak self] result in
            switch result {
            case let .success(data):
                guard let string = String(data: data, encoding: .utf8) else {
                    return
                }
                let response = DappBridgeResponse(
                    invocationId: "",
                    status: .fulfilled,
                    data: .data(string)
                )
                self?.sendResponse(response)
            case .failed:
                break
            }
        }
    }

    func didReceiveMessage(body: Any) {
        Log.d("didReceiveMessage\(body)")
        guard let string = body as? String,
              let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              let messageType = DappBridgeMessageType(rawValue: type),
              messageType == .invokeRnFunc,
              let name = json["name"] as? String,
              let functionType = DappBridgeFunctionType(rawValue: name),
              let invocationId = json["invocationId"] as? String,
              let args = json["args"] as? [Any]
        else {
            return
        }

        let message = DappFunctionInvokeMessage(
            type: functionType,
            invocationId: invocationId,
            args: args
        )

        messageHandler.handleFunctionInvokeMessage(message, dapp: dapp) { [weak self] result in
            switch result {
            case let .success(data):
                guard let string = String(data: data, encoding: .utf8) else {
                    return
                }
                let response = DappBridgeResponse(
                    invocationId: message.invocationId,
                    status: .fulfilled,
                    data: .data(string)
                )
                self?.sendResponse(response)
            case let .failed(error):
                let response = DappBridgeResponse(
                    invocationId: message.invocationId,
                    status: .rejected,
                    data: .error(error)
                )
                self?.sendResponse(response)
            }
        }
    }

    func copyDappURL(url: URL) {
        let resultUrl = if checkIfUrlBlockchainExplorer(url: url) {
            url
        } else {
            updateURLForCopyAndShare(url: url)
        }
        Pasteboard.copy(value: resultUrl.absoluteString)
        sendAnalyticsEvent(action: .copy)
    }

    func shareDappURL(url: URL) {
        if checkIfUrlBlockchainExplorer(url: url) {
            didShareURLSystemShareSheet?(url)
        } else {
            let url = updateURLForCopyAndShare(url: url)
            didShareDappURL?(dapp, url)
        }
        sendAnalyticsEvent(action: .share)
    }

    let dapp: Dapp
    let messageHandler: DappMessageHandler

    private let wallet: Wallet?
    private let analyticsProvider: AnalyticsProvider

    init(
        dapp: Dapp,
        messageHandler: DappMessageHandler,
        wallet: Wallet?,
        analyticsProvider: AnalyticsProvider
    ) {
        self.dapp = dapp
        self.messageHandler = messageHandler
        self.wallet = wallet
        self.analyticsProvider = analyticsProvider
    }

    private func sendResponse(_ response: DappBridgeResponse) {
        guard let responseJson = response.json else { return }
        let js = """
        (function() {
            window.dispatchEvent(new MessageEvent('message', {
                data: \(responseJson)
            }));
        })();
        """
        injectHandler?(js)
    }

    var jsInjection: String? {
        let deviceInfo = TonConnect.DeviceInfo(maxMessages: (try? wallet?.contract.maxMessages) ?? 4, appVersion: InfoProvider.appVersion())
        let info = Info(
            isWalletBrowser: true,
            deviceInfo: deviceInfo,
            protocolVersion: 2
        )

        let theme = TKThemeManager.shared.theme.stringDescription

        guard let infoData = try? JSONEncoder().encode(info),
              var infoString = String(data: infoData, encoding: .utf8) else { return nil }
        infoString = String(describing: infoString).replacingOccurrences(of: "\\", with: "")
        return """
                (() => {
                                if (!window.tonapi) {
                                  window.tonapi = {
                                    fetch: async (url, options) => {
                                      return new Promise((resolve, reject) => {
                                        window.invokeRnFunc('tonapi.fetch', [url, options], (result) => {
                                          try {
                                            const headers = new Headers(result.headers);
                                            const response = new Response(result.body, {
                                              status: result.status,
                                              statusText: result.statusText,
                                              headers: headers
                                            });
                                            resolve(response);
                                          } catch (e) {
                                            reject(e);
                                          }
                                        }, reject)
                                      });
                                    }
                                  };
                                }
                                if (!window.\(String.windowKey)) {
                                    window.rnPromises = {};
                                    window.rnEventListeners = [];
                                    window.invokeRnFunc = (name, args, resolve, reject) => {
                                        const invocationId = btoa(Math.random()).substring(0, 12);
                                        const timeoutMs = null;
                                        const timeoutId = timeoutMs ? setTimeout(() => reject(new Error('bridge timeout for function with name: '+name+'')), timeoutMs) : null;
                                        window.rnPromises[invocationId] = { resolve, reject, timeoutId }
                                        window.webkit.messageHandlers.dapp.postMessage(JSON.stringify({
                                            type: '\(DappBridgeMessageType.invokeRnFunc.rawValue)',
                                            invocationId: invocationId,
                                            name,
                                            args,
                                        }));
                                    };
                                    
                                    window.addEventListener('message', ({ data }) => {
                                        try {
                                            const message = data;
                                            console.log('message bridge', JSON.stringify(message));
                                            if (message.type === '\(DappBridgeMessageType.functionResponse.rawValue)') {
                                                const promise = window.rnPromises[message.invocationId];
                                                
                                                if (!promise) {
                                                    return;
                                                }
                                                
                                                if (promise.timeoutId) {
                                                    clearTimeout(promise.timeoutId);
                                                }
                                                console.log(message)
                                                
                                                if (message.status === 'fulfilled') {
                                                    let messageData = JSON.parse(message.data);
                                                    
                                                    promise.resolve(messageData);
                                                } else {
                                                    promise.reject(new Error(message.data));
                                                }
                                                
                                                delete window.rnPromises[message.invocationId];
                                            }
                                            
                                            if (message.type === '\(DappBridgeMessageType.event.rawValue)') {
                                                window.rnEventListeners.forEach((listener) => listener(message.event));
                                            }
                                        } catch { }
                                    });
                                }
                                
                                const listen = (cb) => {
                                    window.rnEventListeners.push(cb);
                                    return () => {
                                        const index = window.rnEventListeners.indexOf(cb);
                                        if (index > -1) {
                                            window.rnEventListeners.splice(index, 1);
                                        }
                                    };
                                };
                                
                                window.\(String.windowKey) = {
                                    theme: "\(theme)",
                                    unlockOrientation: () => new Promise((resolve, reject) => window.invokeRnFunc('unlockOrientation', [], resolve, reject)),
                                    lockOrientation: () => new Promise((resolve, reject) => window.invokeRnFunc('lockOrientation', [], resolve, reject)),
                                    tonconnect: Object.assign(\(infoString),{ send: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('send', args, resolve, reject))},connect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('connect', args, resolve, reject))},restoreConnection: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('restoreConnection', args, resolve, reject))},disconnect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('disconnect', args, resolve, reject))} },{ listen }),
                                }
                            })();
        """
    }

    private func updateURLForCopyAndShare(url: URL) -> URL {
        let urlEncoded: (URL) -> String? = {
            guard let percenEncodingRemoved = $0
                .absoluteString
                .replacingOccurrences(of: "%25", with: "%")
                .removingPercentEncoding
            else {
                return nil
            }
            let set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
            return (percenEncodingRemoved as NSString).addingPercentEncoding(withAllowedCharacters: set)
        }

        guard let encoded = urlEncoded(url) else { return url }
        guard let updatedUrl = URL(string: "https://app.tonkeeper.com/dapp/\(encoded)") else { return url }
        return updatedUrl
    }

    func checkIfUrlBlockchainExplorer(url: URL) -> Bool {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        return [BlockchainExplorer.tonviewer.host, BlockchainExplorer.tronscan.host].contains(urlComponents?.host)
    }

    private enum Action {
        case copy
        case share
        var value: String {
            switch self {
            case .copy: "Copy link"
            case .share: "Share"
            }
        }
    }

    private func sendAnalyticsEvent(action: Action) {
        analyticsProvider.log(
            eventKey: .dappSharingCopy,
            args: [
                "name": dapp.name,
                "url": dapp.url.absoluteString,
                "from": action.value,
            ]
        )
    }
}

private struct Info: Encodable {
    let isWalletBrowser: Bool
    let deviceInfo: TonConnect.DeviceInfo
    let protocolVersion: Int
}

struct DappFunctionInvokeMessage {
    let type: DappBridgeFunctionType
    let invocationId: String
    let args: [Any]
}

struct DappBridgeResponse {
    enum Status: String {
        case fulfilled
        case rejected
    }

    enum Data {
        case data(String)
        case error(Int)
    }

    let invocationId: String
    let status: Status
    let data: Data

    var json: String? {
        var dictionary: [String: Any] = ["invocationId": invocationId,
                                         "status": status.rawValue,
                                         "type": "functionResponse"]
        switch data {
        case let .data(data):
            dictionary["data"] = data
        case let .error(error):
            dictionary["data"] = error
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let dataString = String(data: data, encoding: .utf8) else { return nil }
        return dataString
    }
}

enum DappBridgeMessageType: String, Codable {
    case invokeRnFunc
    case functionResponse
    case event
}

enum DappBridgeFunctionType: String, Codable {
    case send
    case connect
    case restoreConnection
    case disconnect
    case tonapiFetch = "tonapi.fetch"
    case unlockOrientation
    case lockOrientation
}

private extension String {
    static let windowKey = "tonkeeper"
}
