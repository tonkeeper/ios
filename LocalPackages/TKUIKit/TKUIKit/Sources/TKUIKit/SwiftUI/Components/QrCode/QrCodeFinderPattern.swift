struct QrCodeFinderPattern: Equatable, Sendable {
    var x: Int
    var y: Int
    var size: Int
}

extension QrCodeFinderPattern {
    func contains(x: Int, y: Int) -> Bool {
        self.x ..< self.x + size ~= x && self.y ..< self.y + size ~= y
    }
}
