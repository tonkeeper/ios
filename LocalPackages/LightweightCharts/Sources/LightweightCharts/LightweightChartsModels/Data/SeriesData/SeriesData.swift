import Foundation

public protocol SeriesData: Codable, Sendable {
    /**
     The time of the data
     */
    var time: Time { get }
}
