import TKLogging
import TKUIKit
import UIKit

struct Pasteboard {
    private init() {}

    static func copy(value: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIPasteboard.general.string = value
        ToastPresenter.showToast(configuration: .copied)
        Log.i("🪵 Pasteboard: copied \(value)")
    }
}
