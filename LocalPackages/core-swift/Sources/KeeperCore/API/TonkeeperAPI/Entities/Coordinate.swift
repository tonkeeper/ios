import Foundation

public struct Coordinate: Codable {
    public let x: TimeInterval
    public let y: Double
}

struct ChartEntity: Codable {
    enum CodingKeys: String, CodingKey {
        case coordinates = "data"
    }
    
    let coordinates: [Coordinate]
}
