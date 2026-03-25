import UIKit

public extension UIApplication {
    var isAppStoreEnvironment: Bool {
        !isDebug && !hasEmbeddedMobileProvision && !isAppStoreReceiptSandbox
    }

    var isDebug: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    private var hasEmbeddedMobileProvision: Bool {
        Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }

    private var isAppStoreReceiptSandbox: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
