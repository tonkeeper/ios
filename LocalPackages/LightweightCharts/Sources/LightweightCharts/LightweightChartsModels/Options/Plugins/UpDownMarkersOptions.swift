import Foundation

/**
 Options for the up-down markers plugin.

 The up-down markers plugin displays directional markers on a series indicating
 upward or downward price movements. Use this options type when creating or configuring
 an up-down markers plugin via `SeriesApi.createUpDownMarkersPlugin(options:)`.
 */
public struct UpDownMarkersOptions: Codable, Sendable {
    /**
     Color used for positive (upward) markers.

     When `nil`, the plugin's default positive color is used.
     */
    public var positiveColor: SurfaceColor?

    /**
     Color used for negative (downward) markers.

     When `nil`, the plugin's default negative color is used.
     */
    public var negativeColor: SurfaceColor?

    /**
     Duration in milliseconds that a marker remains visible after it appears.

     When `nil`, markers remain visible indefinitely or use the plugin's default duration.
     */
    public var updateVisibilityDuration: Int?

    public init(
        positiveColor: SurfaceColor? = nil,
        negativeColor: SurfaceColor? = nil,
        updateVisibilityDuration: Int? = nil
    ) {
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.updateVisibilityDuration = updateVisibilityDuration
    }
}

// MARK: - Codable

extension UpDownMarkersOptions {
    enum CodingKeys: String, CodingKey {
        case positiveColor
        case negativeColor
        case updateVisibilityDuration
    }
}

// MARK: - Encodable helper

extension UpDownMarkersOptions {
    func jsonString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
