import SwiftUI
import TKLocalize
import TKUIKit

struct ReceiveActionRowView: View {
    let onCopy: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ReceiveActionButton(
                title: TKLocales.Actions.copy,
                icon: .TKUIKit.Icons.Size16.copy,
                style: .compact,
                action: onCopy
            )

            ReceiveActionButton(
                title: nil,
                icon: .TKUIKit.Icons.Size16.share,
                style: .icon,
                action: onShare
            )
        }
    }
}

private struct ReceiveActionButton: View {
    enum Style {
        case compact
        case icon
    }

    let title: String?
    let icon: UIImage
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SwiftUI.Image(uiImage: icon)
                    .renderingMode(.template)

                if let title {
                    Text(title)
                        .textStyle(.label1)
                }
            }
            .foregroundStyle(.buttonSecondaryForeground)
            .frame(height: 48)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.buttonSecondaryBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .compact:
            20
        case .icon:
            16
        }
    }
}
