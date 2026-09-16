import SwiftUI
import TKUIKit

struct TradeShelfContentView: View {
    let content: TradeShelfViewContent
    let onSelectGrid: (String) -> Void
    let selectedGroupForShelf: (TradeShelfViewData) -> TradeShelfGroupViewData?
    let selectedGridForShelf: (TradeShelfViewData) -> TradeShelfGridViewData?

    var body: some View {
        switch content {
        case let .skeleton(hasHeader, itemsCount):
            AssetsGridView(
                items: .constant((0 ..< itemsCount).map(SkeletonAssetItem.init)),
                itemByModel: { _ in
                    ServiceCardView(config: .shimmer)
                },
                header: {
                    if hasHeader {
                        SegmentedControlShimmer()
                            .padded()
                    }
                }
            )
        case let .content(shelf, _, onOpenAsset):
            if let selectedGroup = selectedGroupForShelf(shelf),
               let selectedGrid = selectedGridForShelf(shelf)
            {
                ShelfTransitionCardView {
                    ShelfCrossfadeView(
                        key: selectedGroup.id,
                        value: ShelfGroupContent(
                            group: selectedGroup,
                            selectedGrid: selectedGrid
                        ),
                        shouldAnimate: ShelfGroupContent.shouldAnimate,
                        content: { groupContent in
                            groupContentView(groupContent, onOpenAsset: onOpenAsset)
                        }
                    )
                }
            }
        }
    }
}

extension TradeShelfContentView {
    private struct SkeletonAssetItem: Identifiable {
        let id: Int
    }

    private struct GridTransitionKey: Hashable {
        var groupID: String
        var gridID: String
    }

    private struct ShelfGroupContent {
        var group: TradeShelfGroupViewData
        var selectedGrid: TradeShelfGridViewData

        var hasSegmentedControl: Bool {
            group.grids.count > 1
        }

        static func shouldAnimate(
            from outgoing: ShelfGroupContent,
            to incoming: ShelfGroupContent
        ) -> Bool {
            if outgoing.hasSegmentedControl != incoming.hasSegmentedControl {
                true
            } else if outgoing.selectedGrid.items.count != incoming.selectedGrid.items.count {
                true
            } else {
                false
            }
        }
    }

    private func groupContentView(
        _ groupContent: ShelfGroupContent,
        onOpenAsset: @escaping (TradeShelfAssetViewData) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            if groupContent.hasSegmentedControl {
                SegmentedControl(
                    segments: groupContent.group.grids.map {
                        .init(id: $0.id, title: $0.name)
                    },
                    initialSelection: groupContent.selectedGrid.id,
                    onSelectionChange: { selectedGridID in
                        onSelectGrid(selectedGridID)
                    }
                ).padded()
            }
            ShelfCrossfadeView(
                key: GridTransitionKey(
                    groupID: groupContent.group.id,
                    gridID: groupContent.selectedGrid.id
                ),
                value: groupContent.selectedGrid,
                shouldAnimate: { outgoing, incoming in
                    outgoing.items.count != incoming.items.count
                }
            ) { grid in
                AssetsGridRowsView(items: grid.items) { item in
                    assetItemView(item, onOpenAsset: onOpenAsset)
                }
            }
        }
    }
}

extension TradeShelfContentView {
    private func assetItemView(
        _ item: TradeShelfAssetViewData,
        onOpenAsset: @escaping (TradeShelfAssetViewData) -> Void
    ) -> some View {
        TradeMarketCardView(
            id: item.id,
            title: item.symbol,
            imageSource: item.iconImageSource,
            changeText: item.changeText,
            changeColor: item.changeColor,
            showsVerificationCheckmark: item.preview.isTrusted == true
        ) {
            onOpenAsset(item)
        }
    }
}

struct TradeMarketCardView<ID: Hashable>: View {
    let id: ID
    let title: String
    let imageSource: AssetAvatarViewImageSource
    let changeText: String?
    let changeColor: TKColor
    var titleTag: TKTagSwiftUIViewConfig?
    var showsVerificationCheckmark = false
    var height: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ServiceCardView(
                config: .content(
                    ServiceCardContent(
                        title: title,
                        imageSource: imageSource,
                        changeConfiguration: changeText.map {
                            .content(text: $0, color: changeColor)
                        },
                        titleTag: titleTag,
                        showsVerificationCheckmark: showsVerificationCheckmark
                    )
                ),
                height: height
            )
        }
        .buttonStyle(ServiceCardHighlightStyle())
        .id(id)
    }
}

// MARK: -

private struct SegmentedControlViewModifier: ViewModifier {
    enum Layout {
        static let headerBottomPadding: CGFloat = 8
        static let headerHorizontalPadding: CGFloat = 8
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Layout.headerHorizontalPadding)
            .padding(.bottom, Layout.headerBottomPadding)
    }
}

private extension View {
    func padded() -> some View {
        modifier(SegmentedControlViewModifier())
    }
}
