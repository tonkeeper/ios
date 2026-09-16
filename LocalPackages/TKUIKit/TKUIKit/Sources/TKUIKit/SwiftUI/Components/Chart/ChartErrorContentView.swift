import SwiftUI
import UIKit

public struct ChartErrorContentView: View {
    private let title: String?

    public init(title: String?) {
        self.title = title
    }

    public var body: some View {
        VStack(spacing: Layout.spacing) {
            SwiftUI.Image.TKUIKit.Artwork.Charts.chartLinePlaceholder
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(.iconTertiary)
                .frame(
                    width: Layout.vectorVisualSize.width,
                    height: Layout.vectorVisualSize.height
                )
                .frame(
                    width: Layout.vectorLayoutSize.width,
                    height: Layout.vectorLayoutSize.height
                )

            if let title, !title.isEmpty {
                Text(title)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Layout.contentHorizontalPadding)
                    .padding(.bottom, Layout.contentBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, Layout.topPadding)
    }
}

private extension ChartErrorContentView {
    enum Layout {
        static let spacing: CGFloat = 29
        static let contentHorizontalPadding: CGFloat = 32
        static let topPadding: CGFloat = 12
        static let contentBottomPadding: CGFloat = 14
        static let vectorLayoutSize = CGSize(width: 119, height: 16)
        static let vectorVisualSize = CGSize(width: 123, height: 20)
    }
}
