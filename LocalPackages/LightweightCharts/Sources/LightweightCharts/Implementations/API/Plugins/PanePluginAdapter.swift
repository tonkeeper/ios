import Foundation

/// Base adapter class for pane plugins.
///
/// This class provides shared functionality for all plugins attached to a chart pane,
/// including JavaScript variable naming strategy and detach behavior.
///
/// Subclasses should:
/// 1. Call the designated initializer with the chart reference and pane index
/// 2. Implement any plugin-specific functionality
/// 3. Optionally override `detach()` if custom cleanup is needed
@MainActor
open class PanePluginAdapter<Chart: JavaScriptObject>: PanePlugin {
    // MARK: - Properties

    /// The JavaScript variable name for this plugin instance.
    ///
    /// This name is generated once during initialization and used
    /// to reference the plugin object in JavaScript.
    public let jsName: String

    /// The JavaScript variable name of the chart.
    private let chartJsName: String

    /// The JavaScript variable name of the stable pane handle.
    private let paneJsName: String

    /// The JavaScript evaluator context for script execution.
    /// Accessible to subclasses for script evaluation.
    private weak var _context: JavaScriptEvaluator?

    /// The JavaScript evaluator context for script execution, if still available.
    var context: JavaScriptEvaluator? {
        _context
    }

    /// Whether this plugin has been detached.
    public private(set) var isDetached: Bool = false

    // MARK: - Initialization

    /// Initializes a new pane plugin adapter.
    ///
    /// - Parameters:
    ///   - chart: The chart this plugin is attached to. Used to access the chart's JavaScript name.
    ///   - paneIndex: The index of the pane this plugin is attached to.
    ///   - context: The JavaScript evaluator context for script execution.
    public init(chart: Chart, paneIndex: Int, context: JavaScriptEvaluator?) {
        self.chartJsName = chart.jsName
        self._context = context
        self.jsName = PanePluginAdapter.makeJSName()
        self.paneJsName = "pane" + .uniqueString

        let script = """
        (function() {
            var panes = \(chartJsName).panes();
            if (!panes || !panes[\(paneIndex)]) {
                throw new Error('Invalid pane index: \(paneIndex). Pane does not exist in this chart.');
            }
            window['\(paneJsName)'] = panes[\(paneIndex)];
        })();
        """
        context?.submitScript(script)
    }

    // MARK: - Plugin Conformance

    /// Detaches (removes) the plugin from the chart.
    ///
    /// After calling this method, the plugin is removed from the chart
    /// and should no longer be used. This is an irreversible operation.
    ///
    /// Subclasses can override this method to perform custom cleanup,
    /// but must call `super.detach()` to ensure proper cleanup.
    public func detach() {
        isDetached = true
    }

    // MARK: - Helper Methods

    /// Evaluates JavaScript code in the chart context.
    ///
    /// - Parameter script: The JavaScript code to evaluate.
    func evaluateScript(_ script: String) {
        guard let context = _context else { return }
        context.submitScript(script)
    }

    func requireContext() throws(JavaScriptBridgeError) -> JavaScriptEvaluator {
        guard let _context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return _context
    }

    /// Evaluates JavaScript code and decodes the result as a specified type.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - type: The type to decode the result as.
    ///   - completion: Completion handler with the decoded result or error.
    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let context = _context else {
            completion(.failure(JavaScriptBridgeError.contextUnavailable))
            return
        }

        if let callbackContext = context as? JavaScriptCallbackEvaluator {
            callbackContext.evaluate(script: script, resultType: resultType, completion: completion)
            return
        }

        completion(.failure(JavaScriptBridgeError.contextUnavailable))
    }

    /// Evaluates JavaScript code and decodes the result as a specified type.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - completion: Completion handler with the decoded result or nil if decoding fails.
    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (T?) -> Void
    ) {
        guard let context = _context else {
            completion(nil)
            return
        }

        guard let callbackContext = context as? JavaScriptCallbackEvaluator else {
            completion(nil)
            return
        }

        callbackContext.decodedResult(forScript: script) { (result: Result<T, Error>) in
            switch result {
            case let .success(value):
                completion(value)
            case .failure:
                completion(nil)
            }
        }
    }

    /// Returns a JavaScript expression that accesses the pane this plugin is attached to.
    ///
    /// This can be used by subclasses to build JavaScript scripts that
    /// operate on the pane.
    ///
    /// - Returns: A JavaScript expression for accessing the pane.
    func paneExpression() -> String {
        return "window['\(paneJsName)']"
    }

    func paneIndexLookupExpression() -> String {
        "\(paneExpression()).paneIndex()"
    }

    /// Returns a guarded script that resolves the plugin pane and creates a JS-backed object.
    ///
    /// - Parameters:
    ///   - objectName: The global window key used to store the created object.
    ///   - factoryCall: The JS factory call that creates the pane-scoped object.
    /// - Returns: A self-contained script that validates the pane and stores the result.
    func paneScopedCreationScript(objectName: String, factoryCall: String) -> String {
        """
        (function() {
            var pane = \(paneExpression());
            var paneIndex = \(paneIndexLookupExpression());
            if (!pane || paneIndex === -1) {
                throw new Error('Pane is no longer attached to this chart.');
            }
            window['\(objectName)'] = \(factoryCall);
        })();
        """
    }

    public func paneIndex() async throws(JavaScriptBridgeError) -> Int {
        let context = try requireContext()
        let paneIndex = try await context.evaluate(script: paneIndexLookupExpression(), resultType: Int.self)
        if paneIndex == -1 {
            throw JavaScriptBridgeError.evaluationFailed(
                script: paneIndexLookupExpression(),
                message: "Pane is no longer attached to this chart."
            )
        }
        return paneIndex
    }

    // MARK: - Private Methods

    /// Generates a unique JavaScript variable name for a plugin instance.
    ///
    /// - Returns: A unique JavaScript variable name.
    private static func makeJSName() -> String {
        return "paneplugin_\(String.uniqueString)"
    }
}
