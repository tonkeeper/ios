import Foundation

/**
 Protocol for series types that support up-down markers plugin.

 Up-down markers are directional indicators that show price movements
 above or below data points. Currently, only LineSeries and AreaSeries
 support this plugin type in the underlying lightweight-charts library.

 This protocol provides compile-time enforcement that UpDownMarkersPlugin
 is only used with compatible series types.
 */
public protocol UpDownMarkersSupported: SeriesApi & SeriesObject {}

// MARK: - Default Conformances

extension LineSeries: UpDownMarkersSupported {}
extension AreaSeries: UpDownMarkersSupported {}
