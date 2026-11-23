import TKLocalize
import TKLogging
import TKUIKit
import UIKit
import UniformTypeIdentifiers

struct Pasteboard {
    private init() {}

    private static let sensitiveExpiry: TimeInterval = 120

    static func copy(value: String, toast: ToastPresenter.Configuration = .copied) {
        UIPasteboard.general.string = value
        ToastPresenter.showToast(configuration: toast)
        Log.i("🪵 Pasteboard: copied \(value)")
    }

    static func copySensitive(value: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(sensitiveExpiry),
            ]
        )
        ToastPresenter.showToast(
            configuration: .confirmed(
                text: TKLocales.Toast.copiedSensitive(Int(sensitiveExpiry))
            )
        )
    }
}
