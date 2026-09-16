import Foundation

/**
 Plugin for managing up-down markers on a chart series.

 This plugin provides visual indicators for directional price movements on a series.
 It wraps the v5 `createUpDownMarkers` primitive.

 The generic parameter is constrained to `UpDownMarkersSupported`, which provides
 compile-time enforcement that only LineSeries and AreaSeries can be used with
 this plugin. These are the only series types supported by the underlying
 lightweight-charts library for up-down markers.

 The plugin can display markers above or below data points to indicate price changes:
 - Positive (upward) movements: shown with positive color
 - Negative (downward) movements: shown with negative color
 - Neutral movements: shown when there's no change

 Use `detach()` to remove the plugin from the series when no longer needed.
 */
@MainActor
public class UpDownMarkersPlugin<Series: UpDownMarkersSupported>: SeriesPluginAdapter<Series>, PluginWithOptions {
    // MARK: - PluginWithOptions Conformance

    public typealias Options = UpDownMarkersOptions

    // MARK: - Properties

    /// The current options applied to this plugin.
    public private(set) var options: UpDownMarkersOptions

    // MARK: - Initialization

    /// Initializes a new up-down markers plugin.
    ///
    /// - Parameters:
    ///   - series: The series this plugin is attached to. Must conform to `UpDownMarkersSupported`
    ///     (i.e., LineSeries or AreaSeries).
    ///   - data: Initial marker data to display.
    ///   - options: Optional initial plugin options.
    public init(series: Series, data: [SeriesUpDownMarker]? = nil, options: UpDownMarkersOptions = UpDownMarkersOptions()) {
        self.options = options
        super.init(series: series)

        // Create the plugin in JavaScript
        // createUpDownMarkers in JS takes (series, options)
        let optionsJson = options.jsonString()
        let script: String
        if optionsJson.isEmpty || optionsJson == "{}" {
            script = "window['\(jsName)'] = LightweightCharts.createUpDownMarkers(\(series.jsName));"
        } else {
            script = "window['\(jsName)'] = LightweightCharts.createUpDownMarkers(\(series.jsName), \(optionsJson));"
        }

        evaluateScript(script)
        if let data = data {
            setMarkers(data)
        }
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

    // MARK: - Data Management

    /// Sets markers on the plugin.
    ///
    /// This replaces any existing markers with the provided data.
    ///
    /// - Parameter data: Array of up-down markers to display. Should be sorted by time.
    public func setMarkers(_ data: [SeriesUpDownMarker]) {
        guard !isDetached, series != nil else { return }

        let script = """
        if (typeof \(jsName).setMarkers === 'function') {
            \(jsName).setMarkers(\(data.jsonString));
        } else if (typeof \(jsName).setData === 'function') {
            \(jsName).setData(\(data.jsonString));
        }
        """
        evaluateScript(script)
    }

    /// Sets markers on the plugin.
    ///
    /// This is an alias for `setMarkers` for backward compatibility.
    ///
    /// - Parameter data: Array of up-down markers to display. Should be sorted by time.
    public func setData(_ data: [SeriesUpDownMarker]) {
        setMarkers(data)
    }

    /// Sets new series data on the plugin.
    ///
    /// This also sets the data on the series the plugin is attached to.
    /// The plugin uses this data to calculate directional price changes
    /// when `update()` is called later.
    ///
    /// - Parameter data: Array of series data (LineData or AreaData).
    public func setData<T: SingleValueSeriesData>(_ data: [T]) {
        guard !isDetached, series != nil else { return }

        let script = "\(jsName).setData(\(data.jsonString));"
        evaluateScript(script)
    }

    /// Updates the plugin with a single series data point.
    ///
    /// This adds or updates the data point for the given time point,
    /// and automatically calculates and displays an up-down marker
    /// by comparing the new value with the previous one.
    ///
    /// - Parameters:
    ///   - bar: The series data point to update.
    ///   - isUpdate: Optional parameter passed to the series update method.
    public func update<T: SingleValueSeriesData>(_ bar: T, isUpdate: Bool? = nil) async throws(JavaScriptBridgeError) {
        guard !isDetached, series != nil else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).update(...)", message: "Plugin has been detached.")
        }

        let isUpdateJson = isUpdate.map { ", \($0 ? "true" : "false")" } ?? ""
        let script = """
        if (typeof \(jsName).update === 'function') {
            \(jsName).update(\(bar.jsonString)\(isUpdateJson));
        } else if (typeof \(jsName).setData === 'function') {
            \(jsName).setData([\(bar.jsonString)]);
        } else {
            throw new Error('UpDownMarkersPlugin does not support update(data).');
        }
        """
        _ = try await requireContext().evaluateScript(script)
    }

    /// Updates the plugin with a single marker.
    ///
    /// This is an overload for backward compatibility. Note that the JS primitive
    /// will still recalculate the up-down sign based on the value change.
    ///
    /// - Parameter marker: The marker to update.
    public func update(_ marker: SeriesUpDownMarker) async throws(JavaScriptBridgeError) {
        guard !isDetached, series != nil else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).update(...)", message: "Plugin has been detached.")
        }

        let script = """
        if (typeof \(jsName).update === 'function') {
            \(jsName).update(\(marker.jsonString));
        } else if (typeof \(jsName).setMarkers === 'function') {
            \(jsName).setMarkers([\(marker.jsonString)]);
        } else {
            throw new Error('UpDownMarkersPlugin does not support update(marker).');
        }
        """
        _ = try await requireContext().evaluateScript(script)
    }

    /// Clears all markers from the plugin.
    ///
    /// This removes all currently displayed markers.
    public func clearMarkers() {
        guard !isDetached, series != nil else { return }

        let script = "\(jsName).clearMarkers();"
        evaluateScript(script)
    }

    /// Returns the current markers displayed on the series.
    public func markers() async throws(JavaScriptBridgeError) -> [SeriesUpDownMarker] {
        guard !isDetached else {
            throw JavaScriptBridgeError.evaluationFailed(script: "\(jsName).markers();", message: "Plugin has been detached.")
        }

        let script = "\(jsName).markers();"
        return try await requireContext().decodedResult(forScript: script)
    }

    /// Returns the current markers displayed on the series.
    ///
    /// - Parameter completion: Completion handler with the array of markers.
    /// - Deprecated: Use `markers() async throws -> [SeriesUpDownMarker]` instead.
    ///   Completion-handler API will be removed in a future major release.
    @available(*, deprecated, message: "Use markers() async throws -> [SeriesUpDownMarker] instead. Completion-handler API will be removed in a future major release.")
    public func getMarkers(completion: @escaping ([SeriesUpDownMarker]?) -> Void) {
        guard !isDetached else {
            completion(nil)
            return
        }

        let script = "\(jsName).markers();"
        decodedResult(forScript: script) { (result: [SeriesUpDownMarker]?) in
            completion(result)
        }
    }

    // MARK: - Options

    /// Applies new options to the plugin.
    ///
    /// Any subset of options can be specified; unspecified options
    /// retain their current values.
    ///
    /// - Parameter options: New options to apply to the plugin.
    public func applyOptions(options: UpDownMarkersOptions) {
        guard !isDetached else { return }

        self.options = options
        let script = "\(jsName).applyOptions(\(options.jsonString()));"
        evaluateScript(script)
    }
}
