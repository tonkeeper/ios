import Foundation

@MainActor
public class SeriesObject: JavaScriptObject {
    public typealias DataChangedContinuation = AsyncStream<DataChangedScope>.Continuation

    nonisolated static var name: String {
        String(describing: self)
    }

    public let jsName: String

    public internal(set) weak var context: JavaScriptEvaluator?
    weak var closureStore: ClosuresStore?
    var chartJSName: String?
    private weak var messageProducer: (any JavaScriptMessageProducer)?
    private let messageHandler: MessageHandler
    private var dataChangedSubscriptionState: Chart.SubscribeState = .declared
    private var manualDataChangedSubscription = false
    private var dataChangedContinuations: [UUID: DataChangedContinuation] = [:]

    public weak var delegate: SeriesDelegate?

    required init(context: JavaScriptEvaluator?, closureStore: ClosuresStore?) {
        self.jsName = Self.name + .uniqueString
        self.context = context
        self.closureStore = closureStore
        self.messageProducer = context as? any JavaScriptMessageProducer
        self.messageHandler = MessageHandler()
        self.messageHandler.delegate = self
    }

    init(context: JavaScriptEvaluator?, closureStore: ClosuresStore?, jsName: String) {
        self.jsName = jsName
        self.context = context
        self.closureStore = closureStore
        self.messageProducer = context as? any JavaScriptMessageProducer
        self.messageHandler = MessageHandler()
        self.messageHandler.delegate = self
    }

    func requireContext() throws(JavaScriptBridgeError) -> JavaScriptEvaluator {
        guard let context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return context
    }

    func activateDataChangedSubscriptionIfNeeded() {
        guard dataChangedSubscriptionState != .active else {
            return
        }

        guard let context, let messageProducer else {
            return
        }

        let name = "\(Subscription.dataChanged.rawValue)_\(jsName)"
        var subscriberScript = ""
        if dataChangedSubscriptionState == .declared {
            subscriberScript = "var \(name) = postMessageFunction('\(name)');"
            messageProducer.addMessageHandler(messageHandler, name: name)
        }
        let script = subscriberScript + "\n\(jsName).subscribeDataChanged(\(name));"
        context.submitScript(script)
        dataChangedSubscriptionState = .active
    }

    func deactivateDataChangedSubscription() {
        guard dataChangedSubscriptionState == .active else {
            return
        }

        guard let context else {
            dataChangedSubscriptionState = .declared
            return
        }

        let name = "\(Subscription.dataChanged.rawValue)_\(jsName)"
        let script = "\(jsName).unsubscribeDataChanged(\(name));"
        context.submitScript(script)
        dataChangedSubscriptionState = .declared
    }

    func deactivateDataChangedSubscriptionIfPossible() {
        guard !manualDataChangedSubscription, dataChangedContinuations.isEmpty else {
            return
        }

        deactivateDataChangedSubscription()
    }

    func subscribeToDataChanged() {
        manualDataChangedSubscription = true
        activateDataChangedSubscriptionIfNeeded()
    }

    func unsubscribeFromDataChanged() {
        manualDataChangedSubscription = false
        deactivateDataChangedSubscriptionIfPossible()
    }

    func makeDataChangedStream() -> AsyncStream<DataChangedScope> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            dataChangedContinuations[id] = continuation
            activateDataChangedSubscriptionIfNeeded()

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.dataChangedContinuations.removeValue(forKey: id)
                    self.deactivateDataChangedSubscriptionIfPossible()
                }
            }
        }
    }

    func yieldDataChanged(_ scope: DataChangedScope) {
        dataChangedContinuations.values.forEach { $0.yield(scope) }
    }
}

extension SeriesObject: MessageHandlerDelegate {
    func messageHandler(_ messageHandler: MessageHandler, didReceiveClickWithParameters parameters: MouseEventParams) {}

    func messageHandler(_ messageHandler: MessageHandler, didReceiveDblClickWithParameters parameters: MouseEventParams) {}

    func messageHandler(_ messageHandler: MessageHandler, didReceiveCrosshairMoveWithParameters parameters: MouseEventParams) {}

    func messageHandler(_ messageHandler: MessageHandler, didReceiveDataChangedWithScope scope: DataChangedScope) {
        if let series = self as? any SeriesApi {
            delegate?.didDataChange(onSeries: series, scope: scope)
        }
        yieldDataChanged(scope)
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveVisibleTimeRangeChangeWithParameters parameters: TimeRange?) {}

    func messageHandler(_ messageHandler: MessageHandler, didReceiveVisibleLogicalRangeChangeWithParameters parameters: LogicalRange?) {}

    func messageHandler(_ messageHandler: MessageHandler, didReceiveTimeScaleSizeChangeWithParameters parameters: Rectangle?) {}
}
