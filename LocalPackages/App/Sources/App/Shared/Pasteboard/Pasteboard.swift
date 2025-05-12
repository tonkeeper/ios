import UIKit
import TKUIKit

struct Pasteboard {
  private init() {}
  
  static func copy(value: String) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = value
    ToastPresenter.showToast(configuration: .copied)
    print("🪵 Pasteboard: copied \(value)")
  }
}
