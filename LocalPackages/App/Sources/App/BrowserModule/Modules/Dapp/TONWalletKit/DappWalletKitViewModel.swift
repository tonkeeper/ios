import Foundation
import KeeperCore
import TKCore
import TKUIKit
import TonSwift
import TONWalletKit
import WebKit

class DappWalletKitViewModel: DappViewModelImplementation {
    let walletKit: TONWalletKit
    let eventsHandler: any TONBridgeEventsHandler

    override var jsInjection: String? {
        let theme = TKThemeManager.shared.theme.stringDescription

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
                                    lockOrientation: () => new Promise((resolve, reject) => window.invokeRnFunc('lockOrientation', [], resolve, reject))
                                }
                            })();
        """
    }

    deinit {
        try? walletKit.remove(eventsHandler: eventsHandler)
    }

    init(
        dapp: Dapp,
        messageHandler: any DappMessageHandler,
        wallet: Wallet?,
        analyticsProvider: AnalyticsProvider,
        walletKit: TONWalletKit,
        eventsHandler: any TONBridgeEventsHandler
    ) {
        self.walletKit = walletKit
        self.eventsHandler = eventsHandler

        super.init(
            dapp: dapp,
            messageHandler: messageHandler,
            wallet: wallet,
            analyticsProvider: analyticsProvider
        )
        try? walletKit.add(eventsHandler: eventsHandler)

        self.webViewCustomizationHandler = { [weak self] webView in
            guard let self else { return }
            do {
                let walletId = try wallet?.walletKitIdentifier
                try webView.inject(
                    walletKit: self.walletKit,
                    configuration: TONBridgeInjectionConfiguration(
                        walletId: walletId
                    )
                )
            } catch {
                debugPrint("Failed to inject TONWalletKit: \(error.localizedDescription)")
            }
        }
    }
}

private extension String {
    static let windowKey = "tonkeeper"
}
