import Foundation
import WebKit

@MainActor
public protocol JavaScriptMessageProducer: AnyObject {
    func addMessageHandler(_ messageHandler: WKScriptMessageHandler, name: String)
}
