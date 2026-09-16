import Foundation

/**
 Plugin for managing an image watermark on a chart pane.

 This plugin wraps the image watermark primitive, providing explicit control
 over watermark lifecycle and options. It implements the `Plugin` protocol
 for consistent plugin management across the library.

 The plugin is attached to a specific pane within the chart and allows:
 - Creating an image watermark with initial options
 - Updating watermark options at runtime via `applyOptions`
 - Replacing the image URL via `updateImage(url:)` (implements detach+recreate)
 - Removing the watermark via `detach`

 Example usage:
 ```swift
 let options = ImageWatermarkOptions(
     alpha: 0.5,
     padding: 10,
     maxWidth: 200,
     maxHeight: 200
 )
 let plugin = ImageWatermarkPlugin(
     chart: chart,
     paneIndex: 0,
     imageUrl: "https://example.com/watermark.png",
     context: context,
     options: options
 )
 // Later update options
 plugin.applyOptions(options: ImageWatermarkUpdateOptions(alpha: 0.3))
 // Replace the image
 plugin.updateImage(url: "https://example.com/new-watermark.png")
 // Remove when done
 plugin.detach()
 ```
 */
@MainActor
public class ImageWatermarkPlugin<Chart: JavaScriptObject>: PanePluginAdapter<Chart>, PluginWithOptions {
    // MARK: - PluginWithOptions Conformance

    public typealias Options = ImageWatermarkOptions

    // MARK: - Properties

    /// The underlying image watermark handle.
    private var watermark: ImageWatermark?

    /// The current options applied to this plugin.
    public private(set) var options: ImageWatermarkOptions

    /// The URL of the image used for the watermark.
    public internal(set) var imageUrl: String

    // MARK: - Initialization

    /// Initializes a new image watermark plugin.
    ///
    /// - Parameters:
    ///   - chart: The chart this plugin is attached to.
    ///   - paneIndex: The index of the pane to attach the watermark to (0 is the main pane).
    ///   - imageUrl: The URL of the image to use as a watermark.
    ///   - context: The JavaScript evaluator context.
    ///   - options: Initial options for the image watermark.
    public init(
        chart: Chart,
        paneIndex: Int,
        imageUrl: String,
        context: JavaScriptEvaluator?,
        options: ImageWatermarkOptions = ImageWatermarkOptions()
    ) {
        self.imageUrl = imageUrl
        self.options = options
        super.init(chart: chart, paneIndex: paneIndex, context: context)

        // Create the image watermark in JavaScript
        let watermarkName = "imageWatermark" + String.uniqueString
        let optionsJson = options.jsonString()
        let imageUrlJson = imageUrl.jsonString()
        let script = paneScopedCreationScript(
            objectName: watermarkName,
            factoryCall: "LightweightCharts.createImageWatermark(pane, \(imageUrlJson), \(optionsJson))"
        )
        evaluateScript(script)

        // Create the watermark handle
        watermark = ImageWatermark(context: context, jsName: watermarkName)
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

    /// Applies new options to the image watermark.
    ///
    /// Any subset of options can be specified; unspecified options
    /// retain their current values.
    ///
    /// - Parameter options: New options to apply to the watermark.
    public func applyOptions(options: ImageWatermarkOptions) {
        guard !isDetached, let watermark = watermark else { return }

        self.options = options
        watermark.applyOptions(options)
    }

    /// Applies a partial options patch to the image watermark.
    ///
    /// Unspecified fields preserve the plugin's current option state.
    ///
    /// - Parameter options: Partial options to apply to the watermark.
    public func applyOptions(options: ImageWatermarkUpdateOptions) {
        guard !isDetached, let watermark = watermark else { return }

        self.options = options.merged(with: self.options)
        watermark.applyOptions(options)
    }

    /// Updates the watermark alpha (transparency).
    ///
    /// This is a convenience method that creates new options with the specified alpha
    /// while preserving other settings.
    ///
    /// - Parameter alpha: The new alpha value (0.0 to 1.0).
    public func setAlpha(_ alpha: Double) {
        applyOptions(options: ImageWatermarkUpdateOptions(alpha: alpha))
    }

    // MARK: - URL Replacement

    /// Updates the watermark image URL.
    ///
    /// Since the upstream lightweight-charts v5 API does not support changing
    /// the image URL via `applyOptions({ url: ... })`, this method implements
    /// URL replacement as a detach+recreate operation:
    /// 1. Detaches the existing watermark
    /// 2. Creates a new watermark with the new URL
    /// 3. Reapplies the current options to the new watermark
    ///
    /// This allows the same plugin instance to display a different image
    /// while maintaining the same options (alpha, padding, size constraints).
    ///
    /// - Parameter url: The new URL of the image to use as a watermark.
    ///                   Can be a regular HTTP(S) URL or a data URL.
    ///
    /// - Note: If the plugin is already detached, this method does nothing.
    public func updateImage(url: String) {
        guard !isDetached else { return }

        // Detach the existing watermark
        watermark?.detach()

        // Update the stored URL
        imageUrl = url

        // Create a new watermark in JavaScript with the new URL
        let watermarkName = "imageWatermark" + String.uniqueString
        let optionsJson = options.jsonString()
        let urlJson = url.jsonString()
        let script = paneScopedCreationScript(
            objectName: watermarkName,
            factoryCall: "LightweightCharts.createImageWatermark(pane, \(urlJson), \(optionsJson))"
        )
        evaluateScript(script)

        // Create the new watermark handle
        if let context = context {
            watermark = ImageWatermark(context: context, jsName: watermarkName)
            // Reapply current options to ensure consistency (matches documented behavior)
            watermark?.applyOptions(self.options)
        }
    }
}
