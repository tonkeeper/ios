import Foundation

/**
 * Structure describing whitespace data item (data point without series' data)
 */
public struct WhitespaceData: SeriesData, Sendable {
    public var time: Time

    public init(time: Time) {
        self.time = time
    }
}
