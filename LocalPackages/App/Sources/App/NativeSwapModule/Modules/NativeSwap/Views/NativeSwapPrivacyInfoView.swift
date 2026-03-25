import SwiftUI
import TKLocalize
import TKUIKit

struct NativeSwapPrivacyInfoView: View {
    var onURLTap: ((URL) -> Void)?

    private var stonfiText: some View {
        Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfi))
    }

    private var termsText: some View {
        HStack(spacing: 4) {
            Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfiTerms))
            Text(String.Symbol.middleDot)
            Text(.init(TKLocales.NativeSwapScreen.Privacy.stonfiPrivacy))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            stonfiText
            termsText
        }
        .font(.body2)
        .foregroundStyle(Color(uiColor: .Text.tertiary))
        .tint(Color(UIColor.Text.secondary))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .environment(\.openURL, OpenURLAction { url in
            onURLTap?(url)
            return .handled
        })
    }
}

private extension Font {
    static var body2: Font {
        .init(TKTextStyle.body2.font)
    }
}
