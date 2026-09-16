import KeeperCore
import TKUIKit

extension CoreAssembly {
    func qrCodeGenerator(persistent: Bool) -> QrCodeMatrixGenerator {
        if persistent {
            QrCodeMatrixGeneratorImplementation
                .persistent(cache: fileSystemVault())
        } else {
            QrCodeMatrixGeneratorImplementation
                .disposable()
        }
    }
}
