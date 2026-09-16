@testable import App
import SwiftUI
import TKUIKit
import XCTest

final class QRCodeViewRenderingTests: XCTestCase {
    @MainActor
    func testQRCodeViewRendersDecodablePayloads() async throws {
        let cases: [(payload: String, configuration: QrCodeGeneratorConfiguration, renderSize: CGSize)] = [
            (QRCodeViewTestConstants.addressPayload, .default, QRCodeViewTestConstants.renderSize),
            (
                QRCodeViewTestConstants.transferPayload,
                QrCodeGeneratorConfiguration(
                    centerCutoutSize: QRCodeViewTestConstants.centerCutoutSize
                ),
                QRCodeViewTestConstants.renderSize
            ),
            // Worst production case: a dense payload (small modules) rendered as
            // dots with the largest production cutout, at a Receive-card-sized
            // canvas. Guards that the erased center stays within ECC tolerance.
            (
                QRCodeViewTestConstants.densePayload,
                QrCodeGeneratorConfiguration(
                    centerCutoutSize: QRCodeViewTestConstants.productionCenterCutoutSize
                ),
                QRCodeViewTestConstants.compactRenderSize
            ),
        ]
        let generator = QrCodeMatrixGeneratorTestFactory.makeGenerator()

        for (payload, configuration, renderSize) in cases {
            let matrix = try XCTUnwrap(
                generator.generateMatrix(
                    string: payload,
                    configuration: configuration
                )
            )
            let image = try await QRCodeViewSnapshotRenderer.render(
                QrCodeView(
                    matrix: matrix,
                    configuration: configuration
                ),
                size: renderSize
            )

            XCTAssertEqual(QRCodeDetector.detectPayload(in: image), payload)
        }
    }
}
