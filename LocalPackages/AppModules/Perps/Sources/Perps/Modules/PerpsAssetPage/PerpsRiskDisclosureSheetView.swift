import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsRiskDisclosureSheetView: View {
    let keeperTermsURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Text(TKLocales.Perps.RiskDisclosure.text)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(links)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .tint(.textAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Layout.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asCellsGroup(config: .init(horizontalPadding: 0))
        .padding(Layout.spacing)
    }

    private var links: AttributedString {
        var line = link(TKLocales.Perps.RiskDisclosure.lighterTerms, url: PerpsTermsURL.lighter)
        if let keeperTermsURL {
            line += AttributedString(" · ")
            line += link(TKLocales.Perps.RiskDisclosure.keeperTerms, url: keeperTermsURL)
        }
        return line
    }

    private func link(_ title: String, url: URL) -> AttributedString {
        var text = AttributedString(title)
        text.link = url
        return text
    }
}

public enum PerpsTermsURL {
    public static let lighter = URL(string: "https://www.keeperwallet.com/terms/lighter")!
}

private enum Layout {
    static let spacing: CGFloat = 16
}
