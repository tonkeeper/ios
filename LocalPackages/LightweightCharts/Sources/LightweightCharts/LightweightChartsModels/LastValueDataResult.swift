import Foundation

public struct LastValueDataResult: Codable, Sendable {
    public var noData: Bool
    public var price: Double?
    public var color: String?

    public init(noData: Bool, price: Double? = nil, color: String? = nil) {
        self.noData = noData
        self.price = price
        self.color = color
    }
}
