@testable import App
import CoreImage
import TKUIKit
import XCTest

final class QrCodeMatrixGeneratorImplementationTests: XCTestCase {
    func testGenerateMatrixMatchesCoreImageMatrix() throws {
        let expectedMatrix = try XCTUnwrap(QrCodeTestMatrix(payload: "test"))
        let matrix = try XCTUnwrap(
            QrCodeMatrixGeneratorTestFactory.makeGenerator().generateMatrix(string: "test")
        )

        XCTAssertEqual(matrix.width, expectedMatrix.width)
        XCTAssertEqual(matrix.height, expectedMatrix.height)
        XCTAssertEqual(matrix.modules, expectedMatrix.modules)
    }

    func testGenerateMatrixProducesMatricesForDecodedPayloadCases() throws {
        let payloads: [(String, QrCodeGeneratorConfiguration)] = [
            (QRCodeViewTestConstants.addressPayload, .default),
            (
                QRCodeViewTestConstants.transferPayload,
                QrCodeGeneratorConfiguration(centerCutoutSize: QRCodeViewTestConstants.centerCutoutSize)
            ),
            (
                Constants.densePayload(length: 450),
                QrCodeGeneratorConfiguration(centerCutoutSize: QRCodeViewTestConstants.centerCutoutSize)
            ),
            (Constants.densePayload(length: 1000), .default),
        ]
        let generator = QrCodeMatrixGeneratorTestFactory.makeGenerator()

        for (payload, configuration) in payloads {
            let matrix = try XCTUnwrap(
                generator.generateMatrix(
                    string: payload,
                    configuration: configuration
                )
            )

            XCTAssertEqual(matrix.width, matrix.height)
            XCTAssertEqual(matrix.modules.count, matrix.width * matrix.height)
            XCTAssertTrue(matrix.modules.contains(true))
            XCTAssertGreaterThanOrEqual(matrix.width, Constants.finderPatternSize)
            XCTAssertGreaterThanOrEqual(matrix.height, Constants.finderPatternSize)
        }
    }

    func testGenerateMatrixUsesCache() throws {
        let generator = QrCodeMatrixGeneratorTestFactory.makeGenerator()

        let firstMatrix = try XCTUnwrap(generator.generateMatrix(string: "test"))
        let cachedMatrix = try XCTUnwrap(generator.generateMatrix(string: "test"))

        XCTAssertEqual(cachedMatrix, firstMatrix)
    }

    func testCacheKeyDescriptionIsFilesystemSafe() {
        let payloads = [
            QRCodeViewTestConstants.addressPayload,
            QRCodeViewTestConstants.transferPayload,
            "EQA/Bc+slashes+and+plus/UQ==",
            QRCodeViewTestConstants.densePayload(length: 2000),
        ]

        for payload in payloads {
            let description = QrCodeMatrixCacheKey(
                string: payload,
                correctionLevel: "M"
            ).description

            XCTAssertFalse(description.contains("/"), "cache filename must not contain a path separator")
            XCTAssertFalse(description.contains(":"), "cache filename must not contain a reserved separator")
            XCTAssertLessThanOrEqual(
                description.utf8.count,
                255,
                "cache filename must stay within the filesystem component length limit"
            )
        }
    }

    func testCacheHitsForPayloadWithPathSeparators() throws {
        let generator = QrCodeMatrixGeneratorTestFactory.makeGenerator()
        let payload = QRCodeViewTestConstants.transferPayload

        let firstMatrix = try XCTUnwrap(generator.generateMatrix(string: payload))
        let cachedMatrix = try XCTUnwrap(generator.generateMatrix(string: payload))

        XCTAssertEqual(cachedMatrix, firstMatrix)
    }

    func testIgnoresCacheEntryWithMismatchedMetadata() throws {
        let vault = QrCodeMatrixGeneratorTestFactory.makeVault()
        let generator = QrCodeMatrixGeneratorTestFactory.makePersistentGenerator(vault: vault)

        let payload = "test"
        let correctionLevel = "M"
        let key = QrCodeMatrixCacheKey(string: payload, correctionLevel: correctionLevel)

        let realMatrix = try XCTUnwrap(generator.generateMatrix(string: payload))

        // Poison the cache entry under this key with a value that belongs to a
        // different payload, simulating a hash collision or a stale record.
        let foreignMatrix = try XCTUnwrap(QrCodeMatrix(width: 1, height: 1, modules: [true]))
        try vault.saveItem(
            CachedQrCodeMatrix(
                string: "different-payload",
                correctionLevel: correctionLevel,
                matrix: foreignMatrix
            ),
            key: key
        )

        let result = try XCTUnwrap(generator.generateMatrix(string: payload))

        XCTAssertEqual(result, realMatrix)
        XCTAssertNotEqual(result, foreignMatrix)
    }

    func testPersistentGeneratorStoresGeneratedMatrixInVault() throws {
        let vault = QrCodeMatrixGeneratorTestFactory.makeVault()
        let generator = QrCodeMatrixGeneratorTestFactory.makePersistentGenerator(vault: vault)

        let payload = "test"
        let key = QrCodeMatrixCacheKey(string: payload, correctionLevel: "M")
        let matrix = try XCTUnwrap(generator.generateMatrix(string: payload))
        let cached = try vault.loadItem(key: key)

        XCTAssertEqual(cached.string, payload)
        XCTAssertEqual(cached.correctionLevel, key.correctionLevel)
        XCTAssertEqual(cached.matrix, matrix)
    }

    func testPersistentGeneratorReadsExistingVaultEntry() throws {
        let vault = QrCodeMatrixGeneratorTestFactory.makeVault()

        let payload = "test"
        let correctionLevel = "M"
        let key = QrCodeMatrixCacheKey(string: payload, correctionLevel: correctionLevel)
        let cachedMatrix = try XCTUnwrap(QrCodeMatrix(width: 1, height: 1, modules: [true]))

        try vault.saveItem(
            CachedQrCodeMatrix(
                string: payload,
                correctionLevel: correctionLevel,
                matrix: cachedMatrix
            ),
            key: key
        )

        let generator = QrCodeMatrixGeneratorTestFactory.makePersistentGenerator(vault: vault)
        let result = try XCTUnwrap(generator.generateMatrix(string: payload))

        XCTAssertEqual(result, cachedMatrix)
    }

    func testDisposableGeneratorDoesNotReadPersistentVaultEntry() throws {
        let vault = QrCodeMatrixGeneratorTestFactory.makeVault()

        let payload = "test"
        let correctionLevel = "M"
        let key = QrCodeMatrixCacheKey(string: payload, correctionLevel: correctionLevel)
        let persistedMatrix = try XCTUnwrap(QrCodeMatrix(width: 1, height: 1, modules: [true]))

        try vault.saveItem(
            CachedQrCodeMatrix(
                string: payload,
                correctionLevel: correctionLevel,
                matrix: persistedMatrix
            ),
            key: key
        )

        let generator = QrCodeMatrixGeneratorTestFactory.makeDisposableGenerator()
        let result = try XCTUnwrap(generator.generateMatrix(string: payload))

        XCTAssertNotEqual(result, persistedMatrix)
    }

    func testDisposableGeneratorDoesNotWriteToPersistentVault() throws {
        let vault = QrCodeMatrixGeneratorTestFactory.makeVault()
        let generator = QrCodeMatrixGeneratorTestFactory.makeDisposableGenerator()

        let payload = "test"
        let key = QrCodeMatrixCacheKey(string: payload, correctionLevel: "M")

        _ = try XCTUnwrap(generator.generateMatrix(string: payload))

        XCTAssertThrowsError(try vault.loadItem(key: key)) { error in
            guard let loadError = error as? QrCodeMatrixGeneratorImplementation.Vault.LoadError else {
                XCTFail("Expected load error, got \(error)")
                return
            }
            guard case .noItem = loadError else {
                XCTFail("Expected noItem error, got \(error)")
                return
            }
        }
    }

    func testGenerateMatrixUsesResolvedAutomaticErrorCorrectionLevel() throws {
        let payload = "test"
        let generator = QrCodeMatrixGeneratorTestFactory.makeGenerator()
        let matrix = try XCTUnwrap(
            generator.generateMatrix(
                string: payload,
                configuration: QrCodeGeneratorConfiguration(
                    centerCutoutSize: QRCodeViewTestConstants.centerCutoutSize
                )
            )
        )
        let expectedMatrix = try XCTUnwrap(
            QrCodeTestMatrix(payload: payload, correctionLevel: "H")
        )

        XCTAssertEqual(matrix.width, expectedMatrix.width)
        XCTAssertEqual(matrix.height, expectedMatrix.height)
        XCTAssertEqual(matrix.modules, expectedMatrix.modules)
    }
}

private struct QrCodeTestMatrix {
    let width: Int
    let height: Int
    let modules: [Bool]

    init?(payload: String, correctionLevel: String = "M") {
        guard let data = payload.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        guard let image = filter.outputImage else { return nil }

        let bounds = image.extent.integral
        let renderedWidth = Int(bounds.width)
        let renderedHeight = Int(bounds.height)
        guard renderedWidth > 0, renderedHeight > 0 else { return nil }

        var bitmap = [UInt8](repeating: 0, count: renderedWidth * renderedHeight * Constants.bytesPerPixel)
        CIContext().render(
            image,
            toBitmap: &bitmap,
            rowBytes: renderedWidth * Constants.bytesPerPixel,
            bounds: bounds,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let renderedModules = (0 ..< renderedHeight).flatMap { y in
            (0 ..< renderedWidth).map { x in
                let index = (y * renderedWidth + x) * Constants.bytesPerPixel
                let red = bitmap[index]
                let alpha = bitmap[index + Constants.alphaOffset]
                return alpha > 0 && red < Constants.darkRedThreshold
            }
        }

        guard let moduleBounds = QrCodeModuleBounds(
            width: renderedWidth,
            height: renderedHeight,
            modules: renderedModules
        ) else {
            return nil
        }

        self.width = moduleBounds.maxX - moduleBounds.minX + 1
        self.height = moduleBounds.maxY - moduleBounds.minY + 1
        self.modules = (moduleBounds.minY ... moduleBounds.maxY).flatMap { y in
            (moduleBounds.minX ... moduleBounds.maxX).map { x in
                renderedModules[y * renderedWidth + x]
            }
        }
    }
}

private struct QrCodeModuleBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

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

        guard maxX >= minX, maxY >= minY else { return nil }
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

private enum Constants {
    static let bytesPerPixel = 4
    static let alphaOffset = 3
    static let darkRedThreshold: UInt8 = 30
    static let finderPatternSize = 7

    static func densePayload(length: Int) -> String {
        let seed = "tonkeeper://transfer/UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ?text="
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let repeated = String(repeating: alphabet, count: max(1, length / alphabet.count + 1))
        return seed + String(repeated.prefix(length))
    }
}
