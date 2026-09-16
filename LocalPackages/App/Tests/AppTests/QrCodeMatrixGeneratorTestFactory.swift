@testable import App
import Foundation
import KeeperCoreComponents
import TKUIKit

enum QrCodeMatrixGeneratorTestFactory {
    static func makeGenerator() -> QrCodeMatrixGeneratorImplementation {
        makePersistentGenerator()
    }

    static func makePersistentGenerator(
        vault: QrCodeMatrixGeneratorImplementation.Vault = makeVault()
    ) -> QrCodeMatrixGeneratorImplementation {
        QrCodeMatrixGeneratorImplementation.persistent(cache: vault)
    }

    static func makeDisposableGenerator() -> QrCodeMatrixGeneratorImplementation {
        QrCodeMatrixGeneratorImplementation.disposable()
    }

    static func makeVault() -> QrCodeMatrixGeneratorImplementation.Vault {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QrCodeMatrixGeneratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        return QrCodeMatrixGeneratorImplementation.Vault(
            fileManager: .default,
            directory: cacheURL
        )
    }
}
