import SwiftUI

public struct TrackableScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let content: () -> Content
    private let onOffsetChange: (CGPoint) -> Void

    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        onOffsetChange: @escaping (CGPoint) -> Void
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
        self.onOffsetChange = onOffsetChange
    }

    public var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            ZStack(alignment: .top) {
                ScrollViewOffsetTracker()
                content()
            }
        }
        .withOffsetTracking(
            action: onOffsetChange
        )
        .tkImmediateButtonPresses()
    }
}

enum ScrollOffsetNamespace {
    static let namespace = "scrollView"
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(
        value: inout CGPoint,
        nextValue: () -> CGPoint
    ) {
        /* empty */
    }
}

struct ScrollViewOffsetTracker: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo
                        .frame(in: .named(ScrollOffsetNamespace.namespace))
                        .origin
                )
        }
        .frame(height: 0)
    }
}

private extension ScrollView {
    func withOffsetTracking(
        action: @escaping (_ offset: CGPoint) -> Void
    ) -> some View {
        coordinateSpace(
            name: ScrollOffsetNamespace.namespace
        ).onPreferenceChange(
            ScrollOffsetPreferenceKey.self,
            perform: action
        )
    }
}
