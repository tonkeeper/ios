import Foundation

/**
 Plugin for managing series markers on a chart series.

 This plugin provides explicit control over markers, including setting/getting markers
 and applying options at runtime. It wraps the v5 `createSeriesMarkers` primitive.

 The plugin can be created on any compatible series type (Line, Bar, Area, etc.).
 Use `detach()` to remove the plugin from the series when no longer needed.
 */
@MainActor
public class SeriesMarkersPlugin<Series: SeriesApi & SeriesObject>: SeriesPluginAdapter<Series>, PluginWithOptions {
    // MARK: - PluginWithOptions Conformance

    public typealias Options = SeriesMarkersOptions

    // MARK: - Properties

    /// The current options applied to this plugin.
    public private(set) var options: SeriesMarkersOptions

    // MARK: - Initialization

    /// Initializes a new series markers plugin.
    ///
    /// - Parameters:
    ///   - series: The series this plugin is attached to.
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    public init(series: Series, data: [SeriesMarker], options: SeriesMarkersOptions = SeriesMarkersOptions()) {
        self.options = options
        super.init(series: series)

        // Create the plugin in JavaScript
        let optionsJson = options.jsonString()
        let script: String
        if optionsJson.isEmpty || optionsJson == "{}" {
            script = "window['\(jsName)'] = LightweightCharts.createSeriesMarkers(\(series.jsName), \(data.jsonString));"
        } else {
            script = "window['\(jsName)'] = LightweightCharts.createSeriesMarkers(\(series.jsName), \(data.jsonString), \(optionsJson));"
        }
        evaluateScript(script)
    }

    // MARK: - Plugin Conformance

    /// Detaches (removes) the plugin from the series.
    ///
    /// After calling this method, the plugin is removed from the chart
    /// and should no longer be used. This is an irreversible operation.
    override public func detach() {
        guard !isDetached else { return }

        let script = "\(jsName).detach();"
        evaluateScript(script)

        super.detach()
    }

    // MARK: - Public Methods

    /// Sets new markers on the series.
    ///
    /// This replaces any existing markers with the provided data.
    ///
    /// - Parameter data: Array of markers to display. Should be sorted by time.
    public func setMarkers(_ data: [SeriesMarker]) {
        guard !isDetached, series != nil else { return }

        let script = "\(jsName).setMarkers(\(data.jsonString));"
        evaluateScript(script)
    }

    /// Returns the current markers displayed on the series.
    public func markers() async throws(JavaScriptBridgeError) -> [SeriesMarker] {
        guard !isDetached else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).markers();", message: "Plugin has been detached.")
        }

        let script = "\(jsName).markers();"
        return try await requireContext().decodedResult(forScript: script)
    }

    /// Returns the current markers displayed on the series.
    ///
    /// - Parameter completion: Completion handler with the array of markers.
    /// - Deprecated: Use `markers() async throws -> [SeriesMarker]` instead.
    ///   Completion-handler API will be removed in a future major release.
    @available(*, deprecated, message: "Use markers() async throws -> [SeriesMarker] instead. Completion-handler API will be removed in a future major release.")
    public func getMarkers(completion: @escaping ([SeriesMarker]?) -> Void) {
        guard !isDetached else {
            completion(nil)
            return
        }

        let script = "\(jsName).markers();"
        decodedResult(forScript: script) { (result: [SeriesMarker]?) in
            completion(result)
        }
    }

    /// Applies new options to the plugin.
    ///
    /// Any subset of options can be specified; unspecified options
    /// retain their current values.
    ///
    /// - Parameter options: New options to apply to the plugin.
    public func applyOptions(options: SeriesMarkersOptions) {
        guard !isDetached else { return }

        self.options = options
        let script = "\(jsName).applyOptions(\(options.jsonString()));"
        evaluateScript(script)
    }
}
