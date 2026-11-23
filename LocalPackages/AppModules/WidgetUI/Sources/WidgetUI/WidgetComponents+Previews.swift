import SwiftUI
import TKUIKit
import WidgetKit

/// Figma's frames: the iPhone 17 Pro's widget sizes; the Lock Screen ones are approximate.
@available(iOS 17.0, *)
extension View {
    func homeWidgetPreview() -> some View {
        background(.backgroundContent)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .tkPreviewTheme(WidgetTheme.resolved)
    }

    func lockWidgetPreview() -> some View {
        environment(\.colorScheme, .dark)
            .background(Color(red: 0.35, green: 0.27, blue: 0.2))
            .tkPreviewTheme(WidgetTheme.resolved)
    }
}

enum WidgetPreviewData {
    static let updatedAt = Calendar.current.date(bySettingHour: 17, minute: 20, second: 0, of: Date())

    static let wallet = WidgetWallet(name: "Main", emoji: nil, icon: Image.TKUIKit.Icons.Size16.walletAvatarWallet)

    /// Deterministic noise around a trend, like a real price line.
    static func chart(from start: Double, to end: Double, points: Int = 60) -> [Double] {
        (0 ..< points).map { index in
            let progress = Double(index) / Double(points - 1)
            let noise = sin(Double(index) * 0.7) * 0.15 + sin(Double(index) * 1.9) * 0.1
            return start + (end - start) * (progress + noise)
        }
    }
}
