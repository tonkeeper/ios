import Foundation

protocol WKWebViewJavascriptBridgeBaseDelegate: AnyObject {
    typealias CompletionHandler = ((Any?, Error?) -> Void)?
    func evaluateJavascript(javascript: String, completion: CompletionHandler)
}

extension WKWebViewJavascriptBridgeBaseDelegate {
    func evaluateJavascript(javascript: String) {
        evaluateJavascript(javascript: javascript, completion: nil)
    }
}

public class WKWebViewJavascriptBridgeBase: NSObject {
    public typealias Callback = (_ responseData: Any?) -> Void
    public typealias Message = [String: Any]
    
    weak var delegate: WKWebViewJavascriptBridgeBaseDelegate?
    var startupMessageQueue: [Message]? = []
    var responseCallbacks = [String: Callback]()
    var uniqueId = 0
    
    func reset() {
        startupMessageQueue = nil
        responseCallbacks = [String: Callback]()
        uniqueId = 0
    }
    
    func send(handlerName: String, data: Any?, callback: Callback?) {
        var message = [String: Any]()
        message["handlerName"] = handlerName
        
        if data != nil {
            message["data"] = data
        }

        if callback != nil {
            uniqueId += 1
            let callbackID = "native_iOS_cb_\(uniqueId)"
            responseCallbacks[callbackID] = callback
            message["callbackID"] = callbackID
        }
        queue(message: message)
    }
    
    func flush(_ message: Any?) {
        guard let messageJSON = message as? String,
              let messages = deserialize(messageJSON: messageJSON) else {
            return
        }
        for message in messages {
            flushMessage(message)
        }
    }
    
    func flushMessage(_ message: Message) {
        if let responseID = message["responseID"] as? String {
            guard let callback = responseCallbacks[responseID] else { return }
            callback(message["responseData"])
            responseCallbacks.removeValue(forKey: responseID)
        } else if let responseID = message["callbackID"] as? String {
            guard let callback = responseCallbacks[responseID] else { return }
            callback(message["responseData"])
            responseCallbacks.removeValue(forKey: responseID)
        }
    }
    
    func injectJavascriptFile() {
        let js = WKWebViewJavascriptBridgeJS
        delegate?.evaluateJavascript(javascript: js, completion: { [weak self] (_, error) in
            guard let self = self else { return }
            if error != nil { return }
            self.startupMessageQueue?.forEach({ (message) in
                self.dispatch(message: message)
            })
            self.startupMessageQueue = nil
        })
    }
    
    private func queue(message: Message) {
        if startupMessageQueue == nil {
            dispatch(message: message)
        } else {
            startupMessageQueue?.append(message)
        }
    }
    
    private func dispatch(message: Message) {
        guard var messageJSON = serialize(message: message, pretty: false) else {
            flushMessage(message)
            return
        }
        
        messageJSON = messageJSON.replacingOccurrences(of: "\\", with: "\\\\")
        messageJSON = messageJSON.replacingOccurrences(of: "\"", with: "\\\"")
        messageJSON = messageJSON.replacingOccurrences(of: "\'", with: "\\\'")
        messageJSON = messageJSON.replacingOccurrences(of: "\n", with: "\\n")
        messageJSON = messageJSON.replacingOccurrences(of: "\r", with: "\\r")
        messageJSON = messageJSON.replacingOccurrences(of: "\u{000C}", with: "\\f")
        messageJSON = messageJSON.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        messageJSON = messageJSON.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        
        let javascriptCommand = "WKWebViewJavascriptBridge._handleMessageFromiOS('\(messageJSON)');"
        self.delegate?.evaluateJavascript(javascript: javascriptCommand)
    }
    
    private func serialize(message: Message, pretty: Bool) -> String? {
        guard JSONSerialization.isValidJSONObject(message),
              let data = try? JSONSerialization.data(withJSONObject: message)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func deserialize(messageJSON: String) -> [Message]? {
        guard let data = messageJSON.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)  else { return nil }
        return result as? [Message]
    }
}
