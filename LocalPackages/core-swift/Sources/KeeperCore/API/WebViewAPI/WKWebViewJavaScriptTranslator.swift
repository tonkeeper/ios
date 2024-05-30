import UIKit
import WebKit

public class WKWebViewJavaScriptTranslator: NSObject {
    private let webView: WKWebView
    let bridge: WKWebViewJavascriptBridge
    
    init(urlPath: URL?) {
        webView = WKWebView(frame: .init(), configuration: .init())
        bridge = WKWebViewJavascriptBridge(webView: webView)
        
        super.init()
                
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        if let urlPath {
            let request = URLRequest(url: urlPath)
            webView.load(request)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func perform(request: String, input: Any?, response: @escaping (Result<Any?, Error>) -> Void) {
        bridge.call(handlerName: request, data: input) { responseData in
            response(.success(responseData))
        }
    }
}

extension WKWebViewJavaScriptTranslator: WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print(123456, message)
        completionHandler()
    }
}

extension WKWebViewJavaScriptTranslator : WKNavigationDelegate {}
