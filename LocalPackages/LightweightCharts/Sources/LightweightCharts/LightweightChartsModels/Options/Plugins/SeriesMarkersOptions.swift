import Foundation

public enum SeriesMarkerZOrder: String, Codable, Sendable {
    case top
    case aboveSeries
    case normal
}

/**
 Options for the series markers plugin.

 The series markers plugin displays custom markers on a series at specific time points.
 Use this options type when creating or configuring a series markers plugin via
 `SeriesApi.createMarkersPlugin(options:)`.
 */
public struct SeriesMarkersOptions: Sendable {
    /**
     Whether the plugin is active and visible.

     When `false`, markers are hidden but not removed.
     */
    public var active: Bool?

    /**
     Whether the price scale should automatically adjust to include markers.

     When `true`, markers are considered when calculating the price scale range.
     */
    public var autoScale: Bool?

    public var zOrder: SeriesMarkerZOrder?

    public init(
        active: Bool? = nil,
        autoScale: Bool? = nil,
        zOrder: SeriesMarkerZOrder? = nil
    ) {
        self.active = active
        self.autoScale = autoScale
        self.zOrder = zOrder
    }
}

// MARK: - Codable

extension SeriesMarkersOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case active
        case autoScale
        case zOrder
    }
}

// MARK: - Encodable helper

extension SeriesMarkersOptions {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
