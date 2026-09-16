import SwiftUI

extension EnvironmentValues {
    var qrCodeTapReaderEnabled: Bool {
        get {
            self[QrCodeTapReaderEnabledKey.self]
        }
        set {
            self[QrCodeTapReaderEnabledKey.self] = newValue
        }
    }
}

private struct QrCodeTapReaderEnabledKey: EnvironmentKey {
    static let defaultValue = true
}
