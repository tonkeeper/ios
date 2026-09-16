import Foundation

/// Series-agnostic control surface for the price-level markers plugin. Lets
/// callers hold and drive the plugin without binding to the concrete series type
/// it was attached to.
@MainActor
public protocol PriceLevelMarkersControlling: Plugin {
    func setMarkers(_ markers: [PriceLevelMarker])
    func applyOptions(options: PriceLevelMarkersOptions)
}

@MainActor
public final class PriceLevelMarkersPlugin<Series: SeriesApi & SeriesObject>: SeriesPluginAdapter<Series>, PluginWithOptions, PriceLevelMarkersControlling {
    public typealias Options = PriceLevelMarkersOptions

    public private(set) var options: PriceLevelMarkersOptions

    public init(series: Series, options: PriceLevelMarkersOptions) {
        self.options = options
        super.init(series: series)

        let script = "window['\(jsName)'] = window.TKLightweightCharts.createPriceLevelMarkers(\(series.jsName), \(options.jsonString));"
        evaluateScript(script)
    }

    override public func detach() {
        guard !isDetached else { return }

        evaluateScript("\(jsName).detach();")
        super.detach()
    }

    public func applyOptions(options: PriceLevelMarkersOptions) {
        guard !isDetached else { return }

        self.options = options
        evaluateScript("\(jsName).applyOptions(\(options.jsonString));")
    }

    public func setMarkers(_ markers: [PriceLevelMarker]) {
        guard !isDetached else { return }

        options.markers = markers
        evaluateScript("\(jsName).setMarkers(\(markers.jsonString));")
    }
}
