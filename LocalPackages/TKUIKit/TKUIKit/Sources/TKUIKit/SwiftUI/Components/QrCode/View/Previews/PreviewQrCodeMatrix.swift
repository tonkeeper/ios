enum PreviewQrCodeMatrix {
    static let sample: QrCodeMatrix = {
        let size = 33
        guard let matrix = QrCodeMatrix(
            width: size,
            height: size,
            modules: makeModules(size: size)
        ) else {
            preconditionFailure("Invalid preview QR matrix")
        }
        return matrix
    }()

    private static func makeModules(size: Int) -> [Bool] {
        (0 ..< size).flatMap { y in
            (0 ..< size).map { x in
                if isFinderPatternModule(x: x, y: y, size: size) {
                    return true
                }

                if x == Constants.timingLine || y == Constants.timingLine {
                    return (x + y).isMultiple(of: 2)
                }

                let value = (x * 31 + y * 17 + x * y * 7 + (x ^ y)) % 13
                return value < 6
            }
        }
    }

    private static func isFinderPatternModule(x: Int, y: Int, size: Int) -> Bool {
        let finderPatternSize = Constants.finderPatternSize
        return x < finderPatternSize && y < finderPatternSize
            || x >= size - finderPatternSize && y < finderPatternSize
            || x < finderPatternSize && y >= size - finderPatternSize
    }

    private enum Constants {
        static let finderPatternSize = 7
        static let timingLine = 6
    }
}
