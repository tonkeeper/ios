import SwiftUI

public struct AssetsGridView<
    ItemModel: Identifiable,
    ItemView: View,
    HeaderView: View
>: View {
    @Binding var items: [ItemModel]

    private let itemByModel: (ItemModel) -> ItemView
    private let header: () -> HeaderView

    public init(
        items: Binding<[ItemModel]>,
        itemByModel: @escaping (ItemModel) -> ItemView,
        @ViewBuilder header: @escaping () -> HeaderView
    ) {
        _items = items
        self.itemByModel = itemByModel
        self.header = header
    }

    public var body: some View {
        VStack(spacing: 0) {
            header()
            AssetsGridRowsView(
                items: items,
                itemByModel: itemByModel
            )
        }
        .padding(.top, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.backgroundContent)
        )
    }
}

/// The row/column layout of an assets grid without the card chrome. Use directly
/// when the card background is provided by a container (e.g. `ShelfTransitionCardView`).
public struct AssetsGridRowsView<ItemModel: Identifiable, ItemView: View>: View {
    private let items: [ItemModel]
    private let itemByModel: (ItemModel) -> ItemView

    public init(
        items: [ItemModel],
        itemByModel: @escaping (ItemModel) -> ItemView
    ) {
        self.items = items
        self.itemByModel = itemByModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< rowCount, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0 ..< columnCount, id: \.self) { columnIndex in
                        if let item = item(rowIndex: rowIndex, columnIndex: columnIndex) {
                            itemByModel(item)
                                .frame(maxWidth: .infinity)
                        } else {
                            Spacer(minLength: 0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private extension AssetsGridRowsView {
    var columnCount: Int {
        min(max(items.count, 1), 4)
    }

    var rowCount: Int {
        guard !items.isEmpty else { return 0 }
        return (items.count + columnCount - 1) / columnCount
    }

    func item(rowIndex: Int, columnIndex: Int) -> ItemModel? {
        let index = rowIndex * columnCount + columnIndex
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }
}

extension AssetsGridView where HeaderView == EmptyView {
    static func view(
        items: Binding<[ItemModel]>,
        itemByModel: @escaping (ItemModel) -> ItemView
    ) -> some View {
        AssetsGridView(
            items: items,
            itemByModel: itemByModel,
            header: { EmptyView() }
        )
    }
}

private struct ItemModel<ID: Hashable>: Identifiable {
    var id: ID
    var symbol: String
    var imageSource: AssetAvatarViewImageSource
    var changeText: String?
    var changeColor: TKColor

    @MainActor
    static func sample(id: ID) -> ItemModel<ID> {
        ItemModel(
            id: id,
            symbol: "TON",
            imageSource: .url(nil, chainIcon: nil),
            changeText: "+ 1.23 %",
            changeColor: .accentGreen
        )
    }

    func createView() -> some View {
        ServiceCardView(
            config: .content(
                ServiceCardContent(
                    title: symbol,
                    imageSource: imageSource,
                    changeConfiguration: changeText.map {
                        .content(
                            text: $0,
                            color: changeColor
                        )
                    }
                )
            )
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0 ..< 8) { index in
                AssetsGridView.view(
                    items: .constant(
                        (0 ... index).map(ItemModel.sample)
                    ),
                    itemByModel: { model in
                        model.createView()
                    }
                )
                .padding(.horizontal, 12)
            }
        }
    }
    .tkImmediateButtonPresses()
    .debugPreview(background: .page)
    .tkThemed()
}
