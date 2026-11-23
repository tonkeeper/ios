import SwiftDraw
import UIKit

public enum SVGImageRasterizer {
    private static let maxByteCount = 1_000_000
    /// SwiftDraw parses the content of a nested <svg> again on each level, so the parse costs about
    /// size × 2^(depth − 1). The budget keeps dapp-controlled input at the cost of a 2 MB flat document.
    private static let maxParsedByteCount = 2_000_000

    public static func rasterize(svgData: Data, maxDimension: CGFloat = 320) -> UIImage? {
        guard svgData.count <= maxByteCount,
              SVGDepthScanner.accepts(svgData, maxDepth: maxSVGDepth(byteCount: svgData.count)),
              let svg = SVG(data: svgData)
        else { return nil }
        let intrinsic = svg.size
        guard intrinsic.width > 0, intrinsic.height > 0 else { return nil }
        let scale = min(maxDimension / intrinsic.width, maxDimension / intrinsic.height)
        let target = CGSize(
            width: (intrinsic.width * scale).rounded(),
            height: (intrinsic.height * scale).rounded()
        )
        // Extreme aspect ratios (or a non-finite size) can round a dimension to 0/NaN.
        guard target.width >= 1, target.height >= 1 else { return nil }
        return svg.rasterize(size: target)
    }

    static func maxSVGDepth(byteCount: Int) -> Int {
        1 + Int(log2(Double(maxParsedByteCount) / Double(max(byteCount, 1))))
    }
}

final class SVGDepthScanner: NSObject, XMLParserDelegate {
    private let limit: Int
    private var depth = 0
    private var rejected = false

    private init(limit: Int) {
        self.limit = limit
    }

    /// Parses like SwiftDraw, which also rejects a document that XMLParser cannot parse.
    static func accepts(_ data: Data, maxDepth: Int) -> Bool {
        let scanner = SVGDepthScanner(limit: maxDepth)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = scanner
        return parser.parse() && !scanner.rejected
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "svg" else { return }
        depth += 1
        if depth > limit { reject(parser) }
    }

    /// XMLParser reports the markup of an internal entity as elements, so the byte count would not bound it.
    /// An unused one is rejected too: icons have no need for markup entities.
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        if value?.contains("<") == true { reject(parser) }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "svg" { depth -= 1 }
    }

    private func reject(_ parser: XMLParser) {
        rejected = true
        parser.abortParsing()
    }
}
