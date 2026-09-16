import SwiftUI
import TKUIKit

#Preview("Safety Check") {
    BackupSafetyCheckPreviewSheet(isConfirmed: false)
}

#Preview("Safety Check — Confirmed") {
    BackupSafetyCheckPreviewSheet(isConfirmed: true)
}

private struct BackupSafetyCheckPreviewSheet: View {
    let isConfirmed: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            BackupSafetyCheckView(isConfirmed: isConfirmed, onContinue: {})
                .clipShape(
                    BackupSafetyCheckPreviewSheetShape(radius: 16)
                )
        }
        .background(.backgroundOverlayStrong)
        .tkPreviewTheme(.deepBlue)
    }
}

private struct BackupSafetyCheckPreviewSheetShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}
