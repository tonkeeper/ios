public struct QrCodeModuleRect: Sendable {
    public var minX: Int
    public var minY: Int
    public var maxX: Int
    public var maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

public extension QrCodeModuleRect {
    func contains(x: Int, y: Int) -> Bool {
        minX ... maxX ~= x && minY ... maxY ~= y
    }
}
