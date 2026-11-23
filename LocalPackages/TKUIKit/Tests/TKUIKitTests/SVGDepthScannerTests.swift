@testable import TKUIKit
import XCTest

final class SVGDepthScannerTests: XCTestCase {
    func testAcceptsNestingUpToTheLimit() {
        XCTAssertTrue(SVGDepthScanner.accepts(nested(depth: 2), maxDepth: 2))
    }

    func testRejectsNestingOverTheLimit() {
        XCTAssertFalse(SVGDepthScanner.accepts(nested(depth: 3), maxDepth: 2))
    }

    func testCountsPrefixedSVGElements() {
        let svg = "<s:svg xmlns:s='http://www.w3.org/2000/svg'><s:svg><s:svg></s:svg></s:svg></s:svg>"
        XCTAssertFalse(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testRejectsDocumentThatStopsParsingBeforeTheNesting() {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg'><title>&nbsp;</title>"
            + String(repeating: "<svg>", count: 24) + String(repeating: "</svg>", count: 25)
        XCTAssertFalse(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testAcceptsUndeclaredXLinkPrefix() {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg'><defs><rect id='r' width='1' height='1'/></defs>"
            + "<use xlink:href='#r'/></svg>"
        XCTAssertTrue(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testRejectsEntityWithMarkup() {
        let svg = "<!DOCTYPE svg [<!ENTITY e \"<rect width='1' height='1'/>\">]>"
            + "<svg xmlns='http://www.w3.org/2000/svg'>&e;</svg>"
        XCTAssertFalse(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testRejectsEntityWithCharacterReferencedMarkup() {
        let svg = "<!DOCTYPE svg [<!ENTITY e \"&#60;rect width='1' height='1'/>\">]>"
            + "<svg xmlns='http://www.w3.org/2000/svg'>&e;</svg>"
        XCTAssertFalse(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testAcceptsNamespaceEntity() {
        let svg = "<!DOCTYPE svg [<!ENTITY ns_svg \"http://www.w3.org/2000/svg\">]>"
            + "<svg xmlns='&ns_svg;'><rect width='1' height='1'/></svg>"
        XCTAssertTrue(SVGDepthScanner.accepts(Data(svg.utf8), maxDepth: 2))
    }

    func testDepthBudgetHalvesTheSizePerLevel() {
        XCTAssertEqual(SVGImageRasterizer.maxSVGDepth(byteCount: 1_000_000), 2)
        XCTAssertEqual(SVGImageRasterizer.maxSVGDepth(byteCount: 500_001), 2)
        XCTAssertEqual(SVGImageRasterizer.maxSVGDepth(byteCount: 500_000), 3)
        XCTAssertEqual(SVGImageRasterizer.maxSVGDepth(byteCount: 250_000), 4)
        XCTAssertEqual(SVGImageRasterizer.maxSVGDepth(byteCount: 0), 21)
    }

    func testRasterizesDeepGroupNestingOnACooperativeThread() async {
        let depth = 250
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'>"
            + String(repeating: "<g>", count: depth) + "<rect width='10' height='10'/>"
            + String(repeating: "</g>", count: depth) + "</svg>"
        let data = Data(svg.utf8)
        let rendered = await Task.detached { SVGImageRasterizer.rasterize(svgData: data) != nil }.value
        XCTAssertTrue(rendered)
    }

    private func nested(depth: Int) -> Data {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg'>"
            + String(repeating: "<svg>", count: depth - 1)
            + String(repeating: "</svg>", count: depth)
        return Data(svg.utf8)
    }
}
