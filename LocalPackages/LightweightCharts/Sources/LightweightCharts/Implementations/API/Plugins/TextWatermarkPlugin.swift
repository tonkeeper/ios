import Foundation

/**
 Plugin for managing a text watermark on a chart pane.

 This plugin wraps the text watermark primitive, providing explicit control
 over watermark lifecycle and options. It implements the `Plugin` protocol
 for consistent plugin management across the library.

 The plugin is attached to a specific pane within the chart and allows:
 - Creating a text watermark with initial options
 - Updating watermark options at runtime via `applyOptions`
 - Removing the watermark via `detach`

 Example usage:
 ```swift
 let options = TextWatermarkOptions(
     text: "Confidential",
     color: "rgba(255, 0, 0, 0.3)",
     fontSize: 48,
     horizontalAlignment: .center,
     verticalAlignment: .center
 )
 let plugin = TextWatermarkPlugin(chart: chart, paneIndex: 0, options: options)
 // Later update options
 plugin.applyOptions(options: TextWatermarkUpdateOptions(visible: false))
 // Remove when done
 plugin.detach()
 ```
 */
@MainActor
public class TextWatermarkPlugin<Chart: JavaScriptObject>: PanePluginAdapter<Chart>, PluginWithOptions {
    // MARK: - PluginWithOptions Conformance

    public typealias Options = TextWatermarkOptions

    // MARK: - Properties

    /// The underlying text watermark handle.
    private var watermark: TextWatermark?

    /// The current options applied to this plugin.
    public private(set) var options: TextWatermarkOptions

    // MARK: - Initialization

    /// Initializes a new text watermark plugin.
    ///
    /// - Parameters:
    ///   - chart: The chart this plugin is attached to.
    ///   - paneIndex: The index of the pane to attach the watermark to (0 is the main pane).
    ///   - context: The JavaScript evaluator context.
    ///   - options: Initial options for the text watermark.
    public init(
        chart: Chart,
        paneIndex: Int,
        context: JavaScriptEvaluator?,
        options: TextWatermarkOptions
    ) {
        self.options = options
        super.init(chart: chart, paneIndex: paneIndex, context: context)

        // Create the text watermark in JavaScript
        let watermarkName = "textWatermark" + String.uniqueString
        let optionsJson = options.jsonString()
        let script = paneScopedCreationScript(
            objectName: watermarkName,
            factoryCall: "LightweightCharts.createTextWatermark(pane, \(optionsJson))"
        )
        evaluateScript(script)

        // Create the watermark handle
        watermark = TextWatermark(context: context, jsName: watermarkName)
    }

    // MARK: - Plugin Conformance

    /// Detaches (removes) the plugin and its watermark from the chart.
    ///
    /// After calling this method, the plugin is removed from the chart
    /// and should no longer be used. This is an irreversible operation.
    override public func detach() {
        guard !isDetached else { return }

        // Detach the underlying watermark
        watermark?.detach()
        watermark = nil

        super.detach()
    }

    // MARK: - Public Methods

    /// Applies new options to the text watermark.
    ///
    /// Any subset of options can be specified; unspecified options
    /// retain their current values.
    ///
    /// - Parameter options: New options to apply to the watermark.
    public func applyOptions(options: TextWatermarkOptions) {
        guard !isDetached, let watermark = watermark else { return }

        self.options = options
        watermark.applyOptions(options)
    }

    /// Applies a partial options patch to the text watermark.
    ///
    /// Unspecified fields preserve the plugin's current option state.
    ///
    /// - Parameter options: Partial options to apply to the watermark.
    public func applyOptions(options: TextWatermarkUpdateOptions) {
        guard !isDetached, let watermark = watermark else { return }

        self.options = options.merged(with: self.options)
        watermark.applyOptions(options)
    }

    /// Returns the current visibility state of the watermark.
    public func visible() async throws(JavaScriptBridgeError) -> Bool {
        guard !isDetached else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).visible", message: "Plugin has been detached.")
        }

        return options.visible
    }

    /// Returns the current visibility state of the watermark.
    ///
    /// - Parameter completion: Completion handler with the visibility state,
    ///   or nil if the plugin has been detached.
    /// - Deprecated: Use `visible() async throws -> Bool` instead.
    ///   Completion-handler API will be removed in a future major release.
    @available(*, deprecated, message: "Use visible() async throws -> Bool instead. Completion-handler API will be removed in a future major release.")
    public func getVisible(completion: @escaping (Bool?) -> Void) {
        guard !isDetached else {
            completion(nil)
            return
        }

        // The options store the current visible state
        completion(options.visible)
    }

    /// Updates the watermark text.
    ///
    /// This is a convenience method that creates new options with the specified text
    /// while preserving other settings from the first line.
    ///
    /// - Parameter text: The new text to display.
    public func setText(_ text: String) {
        guard !isDetached, !options.lines.isEmpty else { return }

        var newOptions = options
        var updatedLines = options.lines
        updatedLines[0] = WatermarkLine(
            text: text,
            color: options.lines[0].color,
            fontSize: options.lines[0].fontSize,
            fontFamily: options.lines[0].fontFamily,
            fontStyle: options.lines[0].fontStyle,
            lineHeight: options.lines[0].lineHeight
        )
        newOptions.lines = updatedLines
        applyOptions(options: newOptions)
    }

    /// Updates the watermark visibility.
    ///
    /// This is a convenience method for toggling watermark visibility.
    ///
    /// - Parameter visible: Whether the watermark should be visible.
    public func setVisible(_ visible: Bool) {
        applyOptions(options: TextWatermarkUpdateOptions(visible: visible))
    }
}
