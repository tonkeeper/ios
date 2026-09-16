import Foundation

public final class OnboardingAssembly {
    public let walletsUpdateAssembly: WalletsUpdateAssembly
    public let storesAssembly: StoresAssembly
    public let deeplinkParser: DeeplinkParser

    init(
        walletsUpdateAssembly: WalletsUpdateAssembly,
        storesAssembly: StoresAssembly,
        deeplinkParser: DeeplinkParser
    ) {
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.storesAssembly = storesAssembly
        self.deeplinkParser = deeplinkParser
    }

    public func scannerAssembly() -> ScannerAssembly {
        ScannerAssembly(deeplinkParser: deeplinkParser)
    }
}
