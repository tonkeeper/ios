import Foundation

public protocol QrCodeMatrixGenerator {
    func generateMatrix(
        string: String,
        configuration: QrCodeGeneratorConfiguration
    ) -> QrCodeMatrix?
}

public extension QrCodeMatrixGenerator {
    func generateMatrix(string: String) -> QrCodeMatrix? {
        generateMatrix(string: string, configuration: .default)
    }
}
