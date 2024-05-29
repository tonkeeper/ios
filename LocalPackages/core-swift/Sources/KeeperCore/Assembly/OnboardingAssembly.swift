import Foundation

public final class OnboardingAssembly {
  
  public let walletsUpdateAssembly: WalletsUpdateAssembly
  public let passcodeAssembly: PasscodeAssembly
  
  init(walletsUpdateAssembly: WalletsUpdateAssembly,
       passcodeAssembly: PasscodeAssembly) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.passcodeAssembly = passcodeAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
}
