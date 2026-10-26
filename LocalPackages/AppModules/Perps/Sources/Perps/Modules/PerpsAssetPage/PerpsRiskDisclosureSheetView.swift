import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsRiskDisclosureSheetView: View {
    let keeperTermsURL: URL?
    let onOK: () -> Void

    var body: some View {
        VStack(spacing: Layout.spacing) {
            VStack(alignment: .leading, spacing: Layout.linksSpacing) {
                Text(TKLocales.Perps.RiskDisclosure.text)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Layout.spacing) {
                    link(TKLocales.Perps.RiskDisclosure.lighterTerms, url: Self.lighterTermsURL)
                    if let keeperTermsURL {
                        link(TKLocales.Perps.RiskDisclosure.keeperTerms, url: keeperTermsURL)
                    }
                }
            }
            .padding(Layout.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .asCellsGroup(config: .init(horizontalPadding: 0))
            ButtonView(config: .init(
                title: TKLocales.Actions.ok,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: onOK
            ))
        }
        .padding(Layout.inset)
    }

    private func link(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .textStyle(.body2)
                .foregroundStyle(.textAccent)
        }
    }

    private static let lighterTermsURL = URL(string: "https://lighter.xyz/terms")!
}

private enum Layout {
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 16
    static let linksSpacing: CGFloat = 12
}
