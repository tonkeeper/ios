import Foundation

@MainActor
public protocol TimeScaleDelegate: AnyObject {
    func didVisibleTimeRangeChange(onTimeScale timeScale: TimeScaleApi, parameters: TimeRange?)
    func didVisibleLogicalRangeChange(onTimeScale timeScale: TimeScaleApi, parameters: LogicalRange?)
    func didReceiveTimeScaleSizeChangeWithParameters(onTimeScale timeScale: TimeScaleApi, parameters: Rectangle?)
}

// MARK: -

@MainActor
class TimeScale: JavaScriptObject {
    enum SubscribeState: CaseIterable {
        case declared
        case active
    }

    typealias Context = JavaScriptEvaluator & JavaScriptMessageProducer

    let jsName = "timeScale" + .uniqueString

    weak var delegate: TimeScaleDelegate?

    private weak var context: Context?
    weak var closureStore: ClosuresStore?
    private let messageHandler: MessageHandler
    private var activeSubscriptions: [Subscription: SubscribeState] = [:]

    init(context: Context?, closureStore: ClosuresStore?) {
        self.context = context
        self.closureStore = closureStore
        messageHandler = MessageHandler()
        messageHandler.delegate = self
    }

    private func requireContext() throws(JavaScriptBridgeError) -> Context {
        guard let context = context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return context
    }

    private func subscriberScript(forName name: String, subscription: Subscription) -> String {
        switch subscription {
        case .crosshairMove, .click:
            return "var \(name) = subscriberCrosshairMoveAndClickFunction('\(name)');"
        default:
            return "var \(name) = postMessageFunction('\(name)');"
        }
    }

    private func subscriberName(for subscription: Subscription) -> String {
        return "\(subscription.rawValue)_\(jsName)"
    }

    private func subscribe(subscription: Subscription) {
        if activeSubscriptions[subscription] == .active {
            NSLog("LWChart: double subscribe detected \(subscription)")
            return
        }
        let name = subscriberName(for: subscription)
        var handlerDeclaration = ""
        if activeSubscriptions[subscription] != .declared {
            handlerDeclaration = subscriberScript(forName: name, subscription: subscription)
            context?.addMessageHandler(messageHandler, name: name)
        }
        let script = handlerDeclaration + "\n\(jsName).subscribe\(subscription.jsRepresentation)(\(name));"
        context?.submitScript(script)
        activeSubscriptions[subscription] = .active
    }

    private func unsubscribe(subscription: Subscription) {
        if activeSubscriptions[subscription] != .active {
            NSLog("LWChart: double unsubscribe detected \(subscription)")
            return
        }
        let name = subscriberName(for: subscription)
        let script = "\(jsName).unsubscribe\(subscription.jsRepresentation)(\(name));"
        context?.submitScript(script)
        activeSubscriptions[subscription] = .declared
    }
}

// MARK: - TimeScaleApi

extension TimeScale: TimeScaleApi {
    // MARK: - Async methods (Swift 6)

    func scrollPosition() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(jsName).scrollPosition();"
        return try await requireContext().evaluate(script: script, resultType: Double.self)
    }

    func getVisibleRange() async throws(JavaScriptBridgeError) -> TimeRange? {
        let script = "\(jsName).getVisibleRange();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func getVisibleLogicalRange() async throws(JavaScriptBridgeError) -> LogicalRange? {
        let script = "\(jsName).getVisibleLogicalRange();"
        return try await requireContext().decodedResult(forScript: script)
    }

    func logicalToCoordinate(logical: Logical) async throws(JavaScriptBridgeError) -> Coordinate? {
        let script = "\(jsName).logicalToCoordinate(\(logical));"
        return try await requireContext().evaluate(script: script, resultType: Coordinate?.self)
    }

    func coordinateToLogical(x: Double) async throws(JavaScriptBridgeError) -> Logical? {
        let script = "\(jsName).coordinateToLogical(\(x));"
        return try await requireContext().evaluate(script: script, resultType: Logical?.self)
    }

    func timeToCoordinate(time: Time) async throws(JavaScriptBridgeError) -> Coordinate? {
        let script = "\(jsName).timeToCoordinate(\(time.jsonString));"
        return try await requireContext().evaluate(script: script, resultType: Coordinate?.self)
    }

    func timeToIndex(time: Time, findNearest: Bool) async throws(JavaScriptBridgeError) -> Int? {
        let script = "\(jsName).timeToIndex(\(time.jsonString), \(findNearest ? "true" : "false"));"
        return try await requireContext().evaluate(script: script, resultType: Int?.self)
    }

    func coordinateToTime(x: Double) async throws(JavaScriptBridgeError) -> Time? {
        let script = "\(jsName).coordinateToTime(\(x));"
        return try await requireContext().decodedResult(forScript: script)
    }

    func width() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(jsName).width();"
        return try await requireContext().evaluate(script: script, resultType: Double.self)
    }

    func height() async throws(JavaScriptBridgeError) -> Double {
        let script = "\(jsName).height();"
        return try await requireContext().evaluate(script: script, resultType: Double.self)
    }

    func options() async throws(JavaScriptBridgeError) -> TimeScaleOptions {
        let script = "\(jsName).options();"
        return try await requireContext().decodedResult(forScript: script)
    }

    // MARK: - Synchronous methods

    func scrollToPosition(position: Double, animated: Bool) {
        let script = "\(jsName).scrollToPosition(\(position), \(animated));"
        context?.submitScript(script)
    }

    func scrollToRealTime() {
        let script = "\(jsName).scrollToRealTime();"
        context?.submitScript(script)
    }

    func setVisibleRange(range: TimeRange) {
        let script = "\(jsName).setVisibleRange(\(range.jsonString));"
        context?.submitScript(script)
    }

    func setVisibleLogicalRange(range: FromToRange<Double>) {
        let script = "\(jsName).setVisibleLogicalRange(\(range.jsonString));"
        context?.submitScript(script)
    }

    func resetTimeScale() {
        let script = "\(jsName).resetTimeScale();"
        context?.submitScript(script)
    }

    func fitContent() {
        let script = "\(jsName).fitContent();"
        context?.submitScript(script)
    }

    func subscribeVisibleTimeRangeChange() {
        subscribe(subscription: .visibleTimeRangeChange)
    }

    func unsubscribeVisibleTimeRangeChange() {
        unsubscribe(subscription: .visibleTimeRangeChange)
    }

    func subscribeVisibleLogicalRangeChange() {
        subscribe(subscription: .visibleLogicalRangeChange)
    }

    func unsubscribeVisibleLogicalRangeChange() {
        unsubscribe(subscription: .visibleLogicalRangeChange)
    }

    func applyOptions(options: TimeScaleOptions) {
        let optionsScript = options.optionsScript(for: closureStore)
        let script = """
        \(optionsScript.options)
        \(jsName).applyOptions(\(optionsScript.variableName));
        """
        context?.submitScript(script)
    }

    func subscribeSizeChange() {
        subscribe(subscription: .timeScaleSizeChange)
    }

    func unsubscribeSizeChange() {
        unsubscribe(subscription: .timeScaleSizeChange)
    }
}

// MARK: - MessageHandlerDelegate

extension TimeScale: MessageHandlerDelegate {
    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveClickWithParameters parameters: MouseEventParams
    ) {}

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveDblClickWithParameters parameters: MouseEventParams
    ) {}

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveCrosshairMoveWithParameters parameters: MouseEventParams
    ) {}

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveDataChangedWithScope scope: DataChangedScope
    ) {}

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveVisibleTimeRangeChangeWithParameters parameters: TimeRange?
    ) {
        delegate?.didVisibleTimeRangeChange(onTimeScale: self, parameters: parameters)
    }

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveVisibleLogicalRangeChangeWithParameters parameters: LogicalRange?
    ) {
        delegate?.didVisibleLogicalRangeChange(onTimeScale: self, parameters: parameters)
    }

    func messageHandler(
        _ messageHandler: MessageHandler,
        didReceiveTimeScaleSizeChangeWithParameters parameters: Rectangle?
    ) {
        delegate?.didReceiveTimeScaleSizeChangeWithParameters(onTimeScale: self, parameters: parameters)
    }
}
