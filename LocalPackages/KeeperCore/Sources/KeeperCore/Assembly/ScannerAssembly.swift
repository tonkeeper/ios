import Foundation

public final class ScannerAssembly {
    public let deeplinkParser: DeeplinkParser

    init(deeplinkParser: DeeplinkParser) {
        self.deeplinkParser = deeplinkParser
    }

    public func scannerController(configurator: ScannerControllerConfigurator) -> ScannerController {
        ScannerController(
            configurator: configurator
        )
    }

    public func signerScanController() -> SignerScanController {
        SignerScanController(deeplinkGenerator: DeeplinkGenerator())
    }
}
