import Foundation

public final class OnboardingAssembly {
  
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  public let passcodeAssembly: PasscodeAssembly
  public let storesAssembly: StoresAssembly
  
  init(walletsUpdateAssembly: WalletsUpdateAssembly,
       passcodeAssembly: PasscodeAssembly,
       storesAssembly: StoresAssembly) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.passcodeAssembly = passcodeAssembly
    self.storesAssembly = storesAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
}
