import Foundation
import WebKit

protocol ClosuresStore: AnyObject {
    func addMethod<Input, Output>(_ method: JavaScriptMethod<Input, Output>, forName name: String)
    func removeAllMethods()
}

// MARK: -

class PromptHandler: NSObject, ClosuresStore {
    private let decoder = JSONDecoder()

    private var closures: [String: JavaScriptSyncMethod] = [:]

    func addMethod<Input: Decodable, Output>(_ method: JavaScriptMethod<Input, Output>, forName name: String) {
        switch method {
        case .closure:
            closures[name] = method
        case .javaScript:
            break
        }
    }

    func removeAllMethods() {
        closures.removeAll()
    }
}

// MARK: - WKUIDelegate

@MainActor
extension PromptHandler: WKUIDelegate {
    struct Payload: Decodable {
        let object: String
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        if let payloadData = prompt.data(using: .utf8, allowLossyConversion: false),
           let payload = try? decoder.decode(Payload.self, from: payloadData)
        {
            let result = closures[payload.object]?.evaluate(payloadData: payloadData, with: decoder)
            completionHandler(result)
        } else {
            completionHandler(defaultText)
        }
    }
}
