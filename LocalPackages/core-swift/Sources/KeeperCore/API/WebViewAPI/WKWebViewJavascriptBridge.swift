import Foundation
import WebKit

public class WKWebViewJavascriptBridge: NSObject {
    private let iOS_Native_InjectJavascript = "iOS_Native_InjectJavascript"
    private let iOS_Native_FlushMessageQueue = "iOS_Native_FlushMessageQueue"
    
    private weak var webView: WKWebView?
    private let base = WKWebViewJavascriptBridgeBase()
    
    public init(webView: WKWebView) {
        super.init()
        self.webView = webView
        base.delegate = self
        addScriptMessageHandlers()
    }
    
    deinit {
        removeScriptMessageHandlers()
    }
    
    public func reset() {
        base.reset()
    }
    
    public func call(handlerName: String, data: Any? = nil, callback: WKWebViewJavascriptBridgeBase.Callback? = nil) {
        base.send(handlerName: handlerName, data: data, callback: callback)
    }
    
    private func flushMessageQueue() {
        webView?.evaluateJavaScript("WKWebViewJavascriptBridge._fetchQueue();") { (result, error) in
            if error != nil {
                print("WKWebViewJavascriptBridge: WARNING: Error when trying to fetch data from WKWebView: \(String(describing: error))")
            }
            self.base.flush(result)
        }
    }
    
    private func addScriptMessageHandlers() {
        webView?.configuration.userContentController.add(self, name: iOS_Native_InjectJavascript)
        webView?.configuration.userContentController.add(self, name: iOS_Native_FlushMessageQueue)
    }
    
    private func removeScriptMessageHandlers() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: iOS_Native_InjectJavascript)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: iOS_Native_FlushMessageQueue)
    }
}

extension WKWebViewJavascriptBridge: WKWebViewJavascriptBridgeBaseDelegate {
    func evaluateJavascript(javascript: String, completion: CompletionHandler) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(javascript, completionHandler: completion)
        }
    }
}

extension WKWebViewJavascriptBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == iOS_Native_InjectJavascript {
            base.injectJavascriptFile()
        }
        
        if message.name == iOS_Native_FlushMessageQueue {
            flushMessageQueue()
        }
    }
}
