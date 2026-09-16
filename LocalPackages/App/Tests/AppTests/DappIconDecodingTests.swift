import TKUIKit
import UIKit
import XCTest

final class DappIconDecodingTests: XCTestCase {
    func testDecodePercentEncodedSVGDataURI() throws {
        let url = try XCTUnwrap(URL(string: "data:image/svg+xml,%3csvg%3e%3c/svg%3e"))
        let data = try XCTUnwrap(DataURIDecoder.decode(url))
        XCTAssertEqual(String(data: data, encoding: .utf8), "<svg></svg>")
    }

    func testDecodeBase64DataURI() throws {
        let payload = Data("<svg/>".utf8).base64EncodedString()
        let url = try XCTUnwrap(URL(string: "data:image/svg+xml;base64,\(payload)"))
        let data = try XCTUnwrap(DataURIDecoder.decode(url))
        XCTAssertEqual(String(data: data, encoding: .utf8), "<svg/>")
    }

    func testDecodeRejectsDataWithoutComma() {
        XCTAssertNil(DataURIDecoder.decode(string: "data:image/svg+xml"))
    }

    func testSniffPlainSVG() {
        XCTAssertTrue(SVGDetection.looksLikeSVG(Data("<svg xmlns='...'></svg>".utf8)))
    }

    func testSniffSVGBehindPrologAndComment() {
        let svg = "<?xml version='1.0'?>\n<!-- generated -->\n<svg></svg>"
        XCTAssertTrue(SVGDetection.looksLikeSVG(Data(svg.utf8)))
    }

    func testSniffRejectsPNGMagic() {
        XCTAssertFalse(SVGDetection.looksLikeSVG(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])))
    }

    func testHeuristicTreatsDataURLAsVector() throws {
        let url = try XCTUnwrap(URL(string: "data:image/svg+xml,%3csvg%3e%3c/svg%3e"))
        XCTAssertTrue(DappIconSource.isVectorLikely(url))
    }

    func testHeuristicTreatsSVGExtensionAsVector() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/assets/logo.SVG"))
        XCTAssertTrue(DappIconSource.isVectorLikely(url))
    }

    func testHeuristicTreatsRasterURLAsNonVector() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/assets/logo.png"))
        XCTAssertFalse(DappIconSource.isVectorLikely(url))
    }

    @MainActor
    func testRasterizeCSSStyledSVGIsNotBlank() throws {
        let svg = Data("""
        <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'>
        <defs><style>.fill{fill:#1e4480;}</style></defs>
        <rect class='fill' width='10' height='10'/>
        </svg>
        """.utf8)
        let image = try XCTUnwrap(SVGImageRasterizer.rasterize(svgData: svg))
        XCTAssertGreaterThan(alpha(of: image), 200, "CSS-styled SVG should rasterize to opaque pixels")
    }

    @MainActor
    func testProviderRendersDataURISVGToDecodablePNG() throws {
        let uri = "data:image/svg+xml,"
            + "%3csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%2010%2010'%3e"
            + "%3cdefs%3e%3cstyle%3e.f%7bfill:%231e4480;%7d%3c/style%3e%3c/defs%3e"
            + "%3crect%20class='f'%20width='10'%20height='10'/%3e%3c/svg%3e"
        let provider = try VectorImageDataProvider(url: XCTUnwrap(URL(string: uri)))

        let expectation = expectation(description: "provider produces data")
        var produced: Data?
        provider.data { result in
            if case let .success(data) = result { produced = data }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let image = try XCTUnwrap(produced.flatMap(UIImage.init(data:)))
        XCTAssertGreaterThan(alpha(of: image), 200)
    }

    private func alpha(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Int(pixel[3])
    }
}
