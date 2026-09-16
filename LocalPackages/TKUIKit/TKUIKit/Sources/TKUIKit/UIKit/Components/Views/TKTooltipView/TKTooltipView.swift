import SwiftUI
import UIKit

public struct TKTooltipView: View {
    public struct Configuration: Equatable {
        public let title: String
        public let badgeTitle: String?
        /// Pass `nil` to let long tooltip titles wrap.
        public let lineLimit: Int?

        public init(title: String, badgeTitle: String? = nil, lineLimit: Int? = 1) {
            self.title = title
            self.badgeTitle = badgeTitle
            self.lineLimit = lineLimit
        }
    }

    public let configuration: Configuration?
    public let position: HintPosition.Direction?

    public init(
        configuration: Configuration?,
        position: HintPosition.Direction? = nil
    ) {
        self.configuration = configuration
        self.position = position
    }

    public var body: some View {
        Group {
            if let configuration {
                HStack(alignment: .top, spacing: Layout.contentSpacing) {
                    if let badgeTitle = configuration.badgeTitle, !badgeTitle.isEmpty {
                        Text(badgeTitle.uppercased())
                            .foregroundStyle(.accentBlue)
                            .textStyle(.body4Bold)
                            .padding(.top, Layout.badgeTopPadding)
                            .padding(.bottom, Layout.badgeBottomPadding)
                            .padding(.horizontal, Layout.badgeHorizontalPadding)
                            .background(.constantWhite)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.badgeCornerRadius))
                    }

                    Text(configuration.title)
                        .foregroundStyle(.constantWhite)
                        .textStyle(.label2)
                        .lineLimit(configuration.lineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Layout.topPadding)
                .padding(.leading, Layout.leadingPadding)
                .padding(.bottom, Layout.bottomPadding)
                .padding(.trailing, Layout.trailingPadding)
                .withTail(
                    appearance: Self.appearance,
                    parameters: Self.tailParameters,
                    direction: position
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("tooltip")
            } else {
                Color.clear
            }
        }
    }
}

extension TKTooltipView: HintView {
    public static var tailParameters: HintTailParameters? {
        HintTailParameters(
            horizontalOffset: Layout.tailOffset,
            size: Layout.tailSize,
            tailCornerRadius: Layout.tailCornerRadius
        )
    }

    public static var appearance: HintAppearance {
        HintAppearance(
            backgroundColor: .accentBlue,
            cornerRadius: Layout.cornerRadius,
            shadowColor: Color.black.opacity(0.04),
            shadowRadius: 8,
            shadowYOffset: 4
        )
    }
}

private extension TKTooltipView {
    enum Layout {
        static let contentSpacing: CGFloat = 6
        static let topPadding: CGFloat = 9
        static let leadingPadding: CGFloat = 14
        static let bottomPadding: CGFloat = 9
        static let trailingPadding: CGFloat = 16
        static let badgeTopPadding: CGFloat = 3
        static let badgeBottomPadding: CGFloat = 3
        static let badgeHorizontalPadding: CGFloat = 5
        static let badgeCornerRadius: CGFloat = 4
        static let cornerRadius: CGFloat = 10
        static let tailSize = CGSize(width: 12, height: 6)
        static let tailOffset: CGFloat = 24
        static let tailCornerRadius: CGFloat = 2
    }
}
