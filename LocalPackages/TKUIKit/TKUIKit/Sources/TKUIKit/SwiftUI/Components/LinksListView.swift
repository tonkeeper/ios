import SwiftUI

struct WrappingHStack<
    Data: RandomAccessCollection,
    Content: View
>: View where Data.Element: Hashable {
    let data: Data
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    init(
        _ data: Data,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + verticalSpacing
                        }

                        let result = width
                        if item == data.last {
                            width = 0
                        } else {
                            width -= dimension.width + horizontalSpacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == data.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { totalHeight = $0 }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public struct LinksListView: View {
    public struct Item: Identifiable, Hashable {
        public var id: String
        public var icon: Image
        public var title: String

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public init(
            id: String,
            icon: Image,
            title: String
        ) {
            self.id = id
            self.icon = icon
            self.title = title
        }
    }

    let items: [Item]
    let onOpened: (Item) -> Void

    public init(items: [Item], onOpened: @escaping (Item) -> Void) {
        self.items = items
        self.onOpened = onOpened
    }

    public var body: some View {
        WrappingHStack(
            items,
            horizontalSpacing: Layout.horizontalSpacing,
            verticalSpacing: Layout.verticalSpacing
        ) { item in
            LinkView(
                icon: item.icon,
                title: item.title,
                onOpen: {
                    onOpened(item)
                }
            )
        }
    }
}

private extension LinksListView {
    enum Layout {
        static let horizontalSpacing: CGFloat = 8
        static let verticalSpacing: CGFloat = 8
    }
}

#Preview {
    LinksListView(
        items: [
            LinksListView.Item(
                id: "1",
                icon: SwiftUI.Image.TKUIKit.Icons.Size16.telegram,
                title: "Community in Telegram"
            ),
            LinksListView.Item(
                id: "2",
                icon: SwiftUI.Image.TKUIKit.Icons.Size16.globe,
                title: "ton.org"
            ),
            LinksListView.Item(
                id: "3",
                icon: SwiftUI.Image.TKUIKit.Icons.Size16.x,
                title: "Community in X"
            ),
        ],
        onOpened: { _ in }
    )
    .border(.cyan)
    .padding(.horizontal, 16)
    .debugPreview(background: .page)
    .tkThemed()
}
