import SwiftUI

struct LinkView: View {
    let icon: Image
    let title: String
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: Layout.contentSpacing) {
                icon
                    .renderingMode(.template)
                    .foregroundStyle(.textPrimary)
                    .frame(maxHeight: .infinity, alignment: .center)
                Text(title)
                    .textStyle(.label2)
                    .foregroundStyle(.buttonSecondaryForeground)
                    .multilineTextAlignment(.leading)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .frame(height: Layout.height)
            .background(
                Capsule(style: .continuous)
                    .fill(.buttonSecondaryBackground)
            )
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }
}

private extension LinkView {
    enum Layout {
        static let contentSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let height: CGFloat = 36
    }
}

#Preview {
    LinkView(
        icon: SwiftUI.Image.TKUIKit.Icons.Size16.telegram,
        title: "Community in Telegram",
        onOpen: {}
    )
    .debugPreview(background: .page)
    .tkThemed()
}
