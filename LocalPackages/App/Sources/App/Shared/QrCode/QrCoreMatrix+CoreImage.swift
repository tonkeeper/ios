import CoreImage
import TKUIKit

extension QrCodeMatrix {
    init?(ciImage: CIImage) {
        let context = CIContext()
        let bounds = ciImage.extent.integral
        let width = Int(bounds.width)
        let height = Int(bounds.height)

        let bytesPerPixel = 4
        let alphaOffset = 3
        let darkThreshold: UInt8 = 128

        guard width > 0, height > 0 else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        context.render(
            ciImage,
            toBitmap: &bitmap,
            rowBytes: width * bytesPerPixel,
            bounds: bounds,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let renderedModules = (0 ..< height)
            .flatMap { y in
                (0 ..< width).map { x in
                    let index = (y * width + x) * bytesPerPixel
                    let red = bitmap[index]
                    let alpha = bitmap[index + alphaOffset]
                    return alpha > 0 && red < darkThreshold
                }
            }

        guard let bounds = QrCodeModuleRect(
            width: width,
            height: height,
            modules: renderedModules
        ) else {
            return nil
        }

        self.init(
            width: bounds.maxX - bounds.minX + 1,
            height: bounds.maxY - bounds.minY + 1,
            modules: (bounds.minY ... bounds.maxY)
                .flatMap { y in
                    (bounds.minX ... bounds.maxX)
                        .map { x in
                            renderedModules[y * width + x]
                        }
                }
        )
    }
}

private extension QrCodeModuleRect {
    init?(width: Int, height: Int, modules: [Bool]) {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0 ..< height {
            for x in 0 ..< width where modules[y * width + x] {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        self.init(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }
}
