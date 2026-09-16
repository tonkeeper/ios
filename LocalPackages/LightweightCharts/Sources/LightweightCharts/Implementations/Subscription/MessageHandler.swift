import Foundation
import WebKit

@MainActor
protocol MessageHandlerDelegate: AnyObject {
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveClickWithParameters parameters: MouseEventParams
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveDblClickWithParameters parameters: MouseEventParams
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveCrosshairMoveWithParameters parameters: MouseEventParams
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveDataChangedWithScope scope: DataChangedScope
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveVisibleTimeRangeChangeWithParameters parameters: TimeRange?
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveVisibleLogicalRangeChangeWithParameters parameters: LogicalRange?
    )
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveTimeScaleSizeChangeWithParameters parameters: Rectangle?
    )
}

// MARK: -

@MainActor
class MessageHandler: NSObject {
    weak var delegate: MessageHandlerDelegate?

    private func decode<T: Decodable>(_ jsonString: String) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(
                domain: "LWChart.MessageHandler",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 encoding in message payload"]
            )
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func handleMessage(name: String, bodyJSONString: String) {
        let nameComponents = name.components(separatedBy: "_")
        if let namePrefix = nameComponents.first,
           let subscription = Subscription(rawValue: namePrefix)
        {
            switch subscription {
            case .click:
                if let parameters: MouseEventParams = try? decode(bodyJSONString) {
                    delegate?.messageHandler(self, didReceiveClickWithParameters: parameters)
                } else {
                    NSLog("LWChart: Failed to decode MouseEventParams for click subscription: \(bodyJSONString)")
                }
            case .dblClick:
                if let parameters: MouseEventParams = try? decode(bodyJSONString) {
                    delegate?.messageHandler(self, didReceiveDblClickWithParameters: parameters)
                } else {
                    NSLog("LWChart: Failed to decode MouseEventParams for dblClick subscription: \(bodyJSONString)")
                }
            case .crosshairMove:
                if let parameters: MouseEventParams = try? decode(bodyJSONString) {
                    delegate?.messageHandler(self, didReceiveCrosshairMoveWithParameters: parameters)
                } else {
                    NSLog("LWChart: Failed to decode MouseEventParams for crosshairMove subscription: \(bodyJSONString)")
                }
            case .dataChanged:
                if let scope: DataChangedScope = try? decode(bodyJSONString) {
                    delegate?.messageHandler(self, didReceiveDataChangedWithScope: scope)
                } else {
                    NSLog("LWChart: Failed to decode DataChangedScope for dataChanged subscription: \(bodyJSONString)")
                }
            case .visibleTimeRangeChange:
                let parameters: TimeRange? = try? decode(bodyJSONString)
                delegate?.messageHandler(self, didReceiveVisibleTimeRangeChangeWithParameters: parameters)
            case .visibleLogicalRangeChange:
                let parameters: LogicalRange? = try? decode(bodyJSONString)
                delegate?.messageHandler(self, didReceiveVisibleLogicalRangeChangeWithParameters: parameters)
            case .timeScaleSizeChange:
                let parameters: Rectangle? = try? decode(bodyJSONString)
                delegate?.messageHandler(self, didReceiveTimeScaleSizeChangeWithParameters: parameters)
            }
        }
    }
}

// MARK: - WKScriptMessageHandler

extension MessageHandler: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let bodyJSONString = message.body as? String else { return }
        handleMessage(name: message.name, bodyJSONString: bodyJSONString)
    }
}
