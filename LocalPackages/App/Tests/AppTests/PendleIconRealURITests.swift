import TKUIKit
import UIKit
import XCTest

final class PendleIconRealURITests: XCTestCase {
    /// The exact `data:image/svg+xml` icon Pendle sends over WalletConnect (raw `{ } '` chars).
    private let pendleURI = "data:image/svg+xml,%3csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%202800.02%203500'%3e%3cdefs%3e%3cstyle%3e.cls-1{fill:%23dedede;}.cls-2{fill:%23152e51;}.cls-3{fill:%231e4480;}%3c/style%3e%3c/defs%3e%3ctitle%3eAsset%203%3c/title%3e%3cg%20id='Layer_2'%20data-name='Layer%202'%3e%3cg%20id='Layer_1-2'%20data-name='Layer%201'%3e%3cpath%20class='cls-1'%20d='M1400.3.25c773.18,0,1400,626.79,1400,1400,0,726.77-553.8,1324.2-1262.43,1393.29a774,774,0,0,0-2.53-150.81c-40.68-355.63-321-636.29-676.55-677.39V110.75l-.68-1.62C1024.85,39,1208.05.25,1400.3.25Z'%20transform='translate(-0.25%20-0.25)'/%3e%3cpath%20class='cls-2'%20d='M683.76,1965.2V198.75l-.65-1.09a1394.58,1394.58,0,0,1,175-88.53l.68,1.62V1965.31c355.5,41.1,635.87,321.76,676.55,677.39a774,774,0,0,1,2.53,150.81q-67.87,6.63-137.54,6.68c-486,0-914.17-247.65-1165.18-623.63A766.63,766.63,0,0,1,682.81,1965.2Z'%20transform='translate(-0.25%20-0.25)'/%3e%3cpath%20class='cls-3'%20d='M1537.84,2793.51c-29.23,359-308.58,659.2-680,701.68-422.5,48.33-804.17-255-852.5-677.5C-23,2570.47,69.16,2337.22,235.12,2176.56c251,376,679.18,623.63,1165.18,623.63Q1469.92,2800.19,1537.84,2793.51Z'%20transform='translate(-0.25%20-0.25)'/%3e%3cpath%20class='cls-1'%20d='M683.76,198.75V1965.2h-1a766.63,766.63,0,0,0-447.69,211.36C86.79,1954.39.32,1687.4.32,1400.22c0-511.05,273.84-958.15,682.79-1202.56Z'%20transform='translate(-0.25%20-0.25)'/%3e%3c/g%3e%3c/g%3e%3c/svg%3e"

    func testURLStringParsesRealPendleDataURI() {
        XCTAssertNotNil(URL(string: pendleURI))
    }

    @MainActor
    func testProviderRendersRealPendleDataURIToNonBlankImage() throws {
        let url = try XCTUnwrap(URL(string: pendleURI))
        let provider = VectorImageDataProvider(url: url)
        let expectation = expectation(description: "provider")
        var produced: Data?
        provider.data { result in
            if case let .success(data) = result { produced = data }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 8)
        let data = try XCTUnwrap(produced, "provider produced no data")
        let image = try XCTUnwrap(UIImage(data: data))
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertGreaterThan(Int(pixel[3]), 40, "rendered Pendle icon is blank")
    }
}
