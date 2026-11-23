import SwiftUI
import TKUIKit

struct StoriesCloseAlertView: View {
    let model: StoriesCloseAlertModel
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(LocalizedStringKey(model.markdownMessage))
                    .font(.body)
            }
            .foregroundStyle(.textPrimary)
            .tint(.textAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8))
            HStack(spacing: 8) {
                button(
                    model.skipTitle,
                    textColor: .textPrimary,
                    background: Color(uiColor: .quaternarySystemFill),
                    action: onSkip
                )
                button(
                    model.continueTitle,
                    textColor: .constantWhite,
                    background: Color(uiColor: .systemBlue),
                    action: onContinue
                )
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundOverlayLight)
    }

    private func button(
        _ title: String,
        textColor: TKColor,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background, in: Capsule())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }
}
