import SwiftUI
import UIKit

public struct TKExpandableTextView: View {
    @Environment(\.tkPalette) private var palette

    private let text: String
    private let collapsedLineLimit: Int
    private let moreTitle: String
    private let lessTitle: String?
    private let style: Style

    @State private var isExpanded = false
    @State private var collapsedTextHeight: CGFloat = .zero
    @State private var expandedTextHeight: CGFloat = .zero

    public init(
        text: String,
        collapsedLineLimit: Int,
        moreTitle: String,
        lessTitle: String? = nil,
        style: Style = .card
    ) {
        self.text = text
        self.collapsedLineLimit = max(collapsedLineLimit, 1)
        self.moreTitle = moreTitle
        self.lessTitle = lessTitle
        self.style = style
    }

    public var body: some View {
        textView
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                if showsMoreButton {
                    moreButton
                }
            }
            .background(measurementContent)
            .onPreferenceChange(TextHeightPreferenceKey.self) { heights in
                if let collapsed = heights[.collapsed] {
                    collapsedTextHeight = collapsed
                }
                if let expanded = heights[.expanded] {
                    expandedTextHeight = expanded
                }
            }
            .onChange(of: text) { _ in
                isExpanded = false
            }
            .onChange(of: collapsedLineLimit) { _ in
                isExpanded = false
            }
            .padding(style.contentInsets)
            .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let backgroundColor = style.backgroundColor {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
    }
}

public extension TKExpandableTextView {
    struct Style {
        public var textStyle: TKTextStyle
        public var textColor: TKColor
        /// Color the trailing fade behind the more button blends into; match the surface the text sits on.
        public var fadeColor: TKColor
        public var backgroundColor: TKColor?
        public var cornerRadius: CGFloat
        public var contentInsets: EdgeInsets

        public init(
            textStyle: TKTextStyle = .body2,
            textColor: TKColor = .textPrimary,
            fadeColor: TKColor = .backgroundContent,
            backgroundColor: TKColor? = .backgroundContent,
            cornerRadius: CGFloat = 16,
            contentInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            self.textStyle = textStyle
            self.textColor = textColor
            self.fadeColor = fadeColor
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.contentInsets = contentInsets
        }

        public static var card: Style {
            Style()
        }

        public static func inline(
            textStyle: TKTextStyle = .body2,
            textColor: TKColor = .textSecondary,
            fadeColor: TKColor = .backgroundContent
        ) -> Style {
            Style(
                textStyle: textStyle,
                textColor: textColor,
                fadeColor: fadeColor,
                backgroundColor: nil,
                cornerRadius: 0,
                contentInsets: EdgeInsets()
            )
        }
    }
}

private extension TKExpandableTextView {
    var textView: some View {
        contentText
            .textStyle(style.textStyle)
            .foregroundStyle(style.textColor)
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : collapsedLineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: collapseIfAllowed)
    }

    var contentText: Text {
        guard isExpanded, let lessTitle else { return Text(text) }
        return Text(text + "  ") + Text(lessTitle).foregroundColor(palette.text.accent)
    }

    func collapseIfAllowed() {
        guard isExpanded, lessTitle != nil else { return }
        withAnimation(.easeInOut(duration: Layout.animationDuration)) {
            isExpanded = false
        }
    }

    var showsMoreButton: Bool {
        !isExpanded && expandedTextHeight > collapsedTextHeight + Layout.heightTolerance
    }

    var measurementContent: some View {
        VStack(spacing: 0) {
            measurementText(lineLimit: collapsedLineLimit, kind: .collapsed)
            measurementText(lineLimit: nil, kind: .expanded)
        }
        .hidden()
        .allowsHitTesting(false)
    }

    func measurementText(
        lineLimit: Int?,
        kind: MeasurementKind
    ) -> some View {
        Text(text)
            .textStyle(style.textStyle)
            .foregroundStyle(Color.clear)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TextHeightPreferenceKey.self,
                        value: [kind: proxy.size.height]
                    )
                }
            )
    }

    var moreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: Layout.animationDuration)) {
                isExpanded = true
            }
        } label: {
            Text(moreTitle)
                .textStyle(style.textStyle)
                .foregroundStyle(.textAccent)
                .padding(.leading, Layout.moreButtonLeadingInset)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: fadeColor.opacity(0), location: 0),
                            .init(color: fadeColor, location: 0.35),
                            .init(color: fadeColor, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: Layout.moreButtonHeight, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(MoreButtonStyle())
    }

    var fadeColor: Color {
        style.fadeColor.resolve(palette)
    }

    enum Layout {
        static let animationDuration: CGFloat = 0.2
        static let heightTolerance: CGFloat = 0.5
        static let moreButtonHeight: CGFloat = 20
        static let moreButtonLeadingInset: CGFloat = 24
    }
}

private enum MeasurementKind: Hashable {
    case collapsed
    case expanded
}

private struct TextHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [MeasurementKind: CGFloat] = [:]

    static func reduce(
        value: inout [MeasurementKind: CGFloat],
        nextValue: () -> [MeasurementKind: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct MoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        TKExpandableTextView(
            text: "Toncoin is TON's native cryptocurrency and deeply integrated into the Telegram ecosystem. Use for Telegram Premium TON payments, network fees, staking, and asset transfers across apps and wallets built on TON.Toncoin is TON's native cryptocurrency and deeply integrated into the Telegram ecosystem. Use for Telegram Premium TON payments, network fees, staking, and asset transfers across apps and wallets built on TON.",
            collapsedLineLimit: 3,
            moreTitle: "More"
        )

        TKExpandableTextView(
            text: "Toncoin is TON's native cryptocurrency and deeply integrated into the Telegram ecosystem.",
            collapsedLineLimit: 5,
            moreTitle: "More"
        )
    }
    .padding(.horizontal, 16)
    .debugPreview(background: .page)
    .tkThemed()
}
