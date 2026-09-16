import Foundation

public struct TradingAssetInfoSource: Equatable, Sendable {
    public var displayedName: String
    public var url: URL?

    public init(displayedName: String, url: URL?) {
        self.displayedName = displayedName
        self.url = url
    }
}
