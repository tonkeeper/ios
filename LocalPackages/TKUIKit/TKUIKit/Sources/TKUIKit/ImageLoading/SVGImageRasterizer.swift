import SVGKit
import UIKit

public enum SVGImageRasterizer {
    private static let maxByteCount = 1_000_000

    @MainActor
    public static func rasterize(svgData: Data, maxDimension: CGFloat = 320) -> UIImage? {
        // Parsing runs synchronously on the main thread on dapp-controlled input, so cap the size.
        guard svgData.count <= maxByteCount, let svg = SVGKImage(data: svgData) else { return nil }
        let intrinsic = svg.size
        guard intrinsic.width > 0, intrinsic.height > 0 else { return nil }
        let scale = min(maxDimension / intrinsic.width, maxDimension / intrinsic.height)
        let target = CGSize(
            width: (intrinsic.width * scale).rounded(),
            height: (intrinsic.height * scale).rounded()
        )
        // Extreme aspect ratios (or a non-finite size) can round a dimension to 0/NaN.
        guard target.width >= 1, target.height >= 1 else { return nil }
        svg.size = target
        // Render the layer tree explicitly; `SVGKImage.uiImage` hangs on some complex SVGs.
        guard let layer = svg.caLayerTree else { return nil }
        return UIGraphicsImageRenderer(size: target).image { context in
            layer.render(in: context.cgContext)
        }
    }
}
