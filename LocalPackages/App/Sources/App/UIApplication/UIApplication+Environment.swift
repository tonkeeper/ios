import UIKit

public extension UIApplication {
  var isAppStoreEnvironment: Bool {
    !hasEmbeddedMobileProvision && !isAppStoreReceiptSandbox
  }
  
  private var hasEmbeddedMobileProvision: Bool {
    Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
  }
  
  private var isAppStoreReceiptSandbox: Bool {
    Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
  }
}
