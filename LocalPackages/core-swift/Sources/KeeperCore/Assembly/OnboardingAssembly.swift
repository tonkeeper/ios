import Foundation

public final class OnboardingAssembly {
  
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  public let storesAssembly: StoresAssembly
  
  init(walletsUpdateAssembly: WalletsUpdateAssembly,
       storesAssembly: StoresAssembly) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.storesAssembly = storesAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
}
