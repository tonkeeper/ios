import SwiftUI
import TKLocalize
import TKUIKit

struct NativeSwapPrivacyInfoView: View {
    var onURLTap: ((URL) -> Void)?
    private var stonfiText: some View {
        Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfi))
            .textStyle(.body2)
    }

    private var termsText: some View {
        HStack(spacing: 4) {
            Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfiTerms))
                .textStyle(.body2)
            Text(String.Symbol.middleDot)
                .textStyle(.body2)
            Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfiPrivacy))
                .textStyle(.body2)
        }
    }

    var body: some View {
        VStack(spacing: -3) {
            stonfiText
            termsText
        }
        .foregroundStyle(.textTertiary)
        .tint(.textSecondary)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .environment(\.openURL, OpenURLAction { url in
            onURLTap?(url)
            return .handled
        })
    }
}
