import CoreImage

public struct QrCodeMatrix: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var modules: [Bool]

    public init?(width: Int, height: Int, modules: [Bool]) {
        guard width > 0, height > 0, modules.count == width * height else {
            return nil
        }
        self.width = width
        self.height = height
        self.modules = modules
    }
}

extension QrCodeMatrix {
    func isDark(x: Int, y: Int) -> Bool {
        guard 0 ..< width ~= x, 0 ..< height ~= y else {
            return false
        }
        return modules[y * width + x]
    }

    var finderPatterns: [QrCodeFinderPattern] {
        let size = QrCodeConstants.finderPatternSize

        guard width >= size, height >= size else {
            return []
        }

        return [
            QrCodeFinderPattern(x: 0, y: 0, size: size),
            QrCodeFinderPattern(x: width - size, y: 0, size: size),
            QrCodeFinderPattern(x: 0, y: height - size, size: size),
        ]
    }
}
