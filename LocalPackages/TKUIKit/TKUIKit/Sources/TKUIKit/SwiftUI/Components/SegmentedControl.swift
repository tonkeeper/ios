import SwiftUI

private struct SegmentedControlStyle: ViewModifier {
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @Environment(\.tkPalette) private var palette

    func body(content: Content) -> some View {
        content
            .frame(height: 40)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private var backgroundColor: Color {
        switch resolvedTheme {
        case .light:
            palette.background.contentAlternate
        case .dark:
            palette.background.transparent
        case .deepBlue:
            palette.background.overlayExtraLight
        }
    }
}

private struct SegmentedControlButtonStyle<Selection: Hashable>: ButtonStyle {
    let segmentID: Selection
    @Binding var pressedSegmentID: Selection?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                pressedSegmentID = isPressed ? segmentID : nil
            }
    }
}

private struct SegmentBoundsPreferenceKey<Selection: Hashable>: PreferenceKey {
    static var defaultValue: [Selection: Anchor<CGRect>] {
        [:]
    }

    static func reduce(
        value: inout [Selection: Anchor<CGRect>],
        nextValue: () -> [Selection: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private extension View {
    func segmentedControlStyle() -> some View {
        modifier(SegmentedControlStyle())
    }
}

public struct SegmentedControlShimmer: View {
    public init() {}

    public var body: some View {
        ShimmerSwiftUIView()
            .frame(maxWidth: .infinity)
            .segmentedControlStyle()
    }
}

public struct SegmentedControl<Selection: Hashable>: View {
    @Environment(\.tkResolvedTheme) private var resolvedTheme
    @Environment(\.tkPalette) private var palette

    private let segments: [Segment]
    private let initialSelection: Selection
    private let onSelectionChange: (Selection) -> Void

    @State private var selectedSegmentID: Selection
    @State private var pressedSegmentID: Selection?

    public init(
        segments: [Segment],
        initialSelection: Selection,
        onSelectionChange: @escaping (Selection) -> Void
    ) {
        self.segments = segments
        self.initialSelection = initialSelection
        self.onSelectionChange = onSelectionChange
        _selectedSegmentID = State(initialValue: initialSelection)
    }

    public var body: some View {
        HStack(spacing: 1) {
            ForEach(segments) { segment in
                segmentButton(segment)
            }
        }
        .backgroundPreferenceValue(SegmentBoundsPreferenceKey<Selection>.self) { preferences in
            selectionBackground(preferences)
        }
        .padding(4)
        .segmentedControlStyle()
        .onChange(of: initialSelection) { initialSelection in
            guard selectedSegmentID != initialSelection else { return }
            setSelectedSegmentID(initialSelection)
        }
    }
}

public extension SegmentedControl {
    internal enum Layout {
        static var iconSize: CGFloat {
            20
        }
    }

    struct Icon {
        public var image: UIImage
        public var size: CGFloat

        public init(
            image: UIImage,
            size: CGFloat? = nil
        ) {
            self.image = image
            self.size = size ?? Layout.iconSize
        }
    }

    struct Segment: Identifiable {
        public var id: Selection
        public var title: String
        public var icon: Icon?

        public init(
            id: Selection,
            title: String,
            icon: Icon? = nil
        ) {
            self.id = id
            self.title = title
            self.icon = icon
        }
    }
}

private extension SegmentedControl {
    func segmentButton(_ segment: Segment) -> some View {
        Button {
            select(segment.id)
        } label: {
            segmentContent(segment)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            SegmentedControlButtonStyle(
                segmentID: segment.id,
                pressedSegmentID: $pressedSegmentID
            )
        )
        .frame(maxWidth: .infinity)
        .anchorPreference(
            key: SegmentBoundsPreferenceKey<Selection>.self,
            value: .bounds
        ) { anchor in
            [segment.id: anchor]
        }
    }

    func selectionBackground(_ preferences: [Selection: Anchor<CGRect>]) -> some View {
        GeometryReader { proxy in
            if let anchor = preferences[selectedSegmentID] {
                let rect = proxy[anchor]
                Capsule(style: .continuous)
                    .fill(selectedItemBackgroundColor)
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(isSelectedSegmentPressed ? TapAnimation.scale : 1)
                    .offset(x: rect.minX, y: rect.minY)
                    .animation(selectionChangeAnimation, value: selectedSegmentID)
                    .animation(tapAnimation, value: pressedSegmentID)
            }
        }
    }

    func segmentContent(_ segment: Segment) -> some View {
        HStack(spacing: 4) {
            if let icon = segment.icon {
                Image(uiImage: icon.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: icon.size, height: icon.size)
            }
            Text(segment.title)
                .textStyle(.label2)
                .padding([.leading], 1)
                .foregroundStyle(foregroungColor)
        }
        .padding(.vertical, 6)
    }

    func select(_ segmentID: Selection) {
        guard selectedSegmentID != segmentID else { return }

        setSelectedSegmentID(segmentID)
        TKTapAnimationHaptic.soft.impactOccurred()

        onSelectionChange(segmentID)
    }

    func setSelectedSegmentID(_ segmentID: Selection) {
        withAnimation(selectionChangeAnimation) {
            selectedSegmentID = segmentID
        }
    }

    private var selectionChangeAnimation: Animation {
        .spring(response: 0.28, dampingFraction: 0.84)
    }

    private var tapAnimation: Animation {
        isSelectedSegmentPressed ? TapAnimation.pressAnimation : TapAnimation.releaseAnimation
    }

    private var isSelectedSegmentPressed: Bool {
        pressedSegmentID == selectedSegmentID
    }

    private var foregroungColor: Color {
        switch resolvedTheme {
        case .light:
            palette.text.primary
        case .dark, .deepBlue:
            palette.button.primaryForeground
        }
    }

    private var selectedItemBackgroundColor: Color {
        switch resolvedTheme {
        case .light:
            palette.button.primaryForeground
        case .dark, .deepBlue:
            palette.button.tertiaryBackground
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        SegmentedControl(
            segments: [
                SegmentedControl.Segment(
                    id: "1",
                    title: "2 Min",
                    icon: SegmentedControl<String>.Icon(
                        image: .TKUIKit.Icons.Size28.clock
                    )
                ),
                SegmentedControl.Segment(
                    id: "2",
                    title: "Top Losers"
                ),
            ],
            initialSelection: "1",
            onSelectionChange: { _ in }
        )
        SegmentedControlShimmer()
    }
    .padding(.horizontal, 24)
    .debugPreview()
}
