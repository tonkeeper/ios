import SwiftUI

private struct PreviewAsset: Identifiable {
    let id: String
    var symbol: String
    var changeText: String
    var changeColor: TKColor
}

private struct PreviewGrid: Identifiable {
    let id: String
    var name: String
    var items: [PreviewAsset]
}

private struct PreviewGroup: Identifiable {
    let id: String
    var title: String
    var grids: [PreviewGrid]
}

private enum PreviewData {
    static let groups: [PreviewGroup] = [
        PreviewGroup(
            id: "all",
            title: "All Networks",
            grids: [
                PreviewGrid(id: "market-cap", name: "Market Cap", items: assets(count: 8)),
                PreviewGrid(id: "volume", name: "Volume", items: assets(count: 3)),
                PreviewGrid(id: "gainers", name: "Gainers", items: assets(count: 5)),
                PreviewGrid(id: "losers", name: "Losers", items: assets(count: 5)),
            ]
        ),
        PreviewGroup(
            id: "ton",
            title: "TON",
            grids: [
                PreviewGrid(id: "trending", name: "Trending", items: assets(count: 8)),
                PreviewGrid(id: "new", name: "New", items: assets(count: 2)),
            ]
        ),
        PreviewGroup(
            id: "solana",
            title: "Solana",
            grids: [
                PreviewGrid(id: "solana-all", name: "All", items: assets(count: 4)),
            ]
        ),
        PreviewGroup(
            id: "tron",
            title: "TRON",
            grids: [
                PreviewGrid(id: "tron-all", name: "All", items: assets(count: 4)),
            ]
        ),
    ]

    static func assets(count: Int) -> [PreviewAsset] {
        let symbols = ["TON", "DOGE", "PEPE", "WIF", "USDT", "NOT", "BTC", "ETH"]
        return (0 ..< count).map { index in
            let isPositive = index % 3 != 2
            return PreviewAsset(
                id: "\(index)",
                symbol: symbols[index % symbols.count],
                changeText: isPositive ? "+ 1.23 %" : "− 4.56 %",
                changeColor: isPositive ? .accentGreen : .accentRed
            )
        }
    }
}

/// Debug harness for the shelf transition: switch grids via the segmented control,
/// switch groups via the buttons (including a single-grid group so the header
/// appears/disappears), and slow the animation down to inspect the phases.
/// Switches that keep both the item count and the header visibility swap instantly:
/// Gainers ↔ Losers, All Networks ↔ TON, Solana ↔ TRON.
private struct ShelfTransitionPreviewHarness: View {
    private struct GroupSnapshot {
        var group: PreviewGroup
        var selectedGrid: PreviewGrid
    }

    @State private var selectedGroupID = PreviewData.groups[0].id
    @State private var selectedGridID = PreviewData.groups[0].grids[0].id
    @State private var isSlowMotion = false

    private var selectedGroup: PreviewGroup {
        PreviewData.groups.first { $0.id == selectedGroupID } ?? PreviewData.groups[0]
    }

    private var selectedGrid: PreviewGrid {
        selectedGroup.grids.first { $0.id == selectedGridID } ?? selectedGroup.grids[0]
    }

    private var configuration: ShelfTransitionConfiguration {
        ShelfTransitionConfiguration(speed: isSlowMotion ? 0.25 : 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                groupPicker
                shelfCard
                Toggle("Slow motion (4x)", isOn: $isSlowMotion)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                Text("Content below the shelf follows the height morph.")
                    .textStyle(.body2)
                    .foregroundStyle(.textTertiary)
            }
            .padding(16)
        }
        .tkImmediateButtonPresses()
    }

    private var groupPicker: some View {
        HStack(spacing: 8) {
            ForEach(PreviewData.groups) { group in
                Button {
                    selectGroup(group)
                } label: {
                    Text(group.title)
                        .textStyle(.label2)
                        .foregroundStyle(group.id == selectedGroupID ? .textPrimary : .textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(group.id == selectedGroupID ? .buttonSecondaryBackground : .backgroundContent)
                        )
                }
            }
        }
    }

    private var shelfCard: some View {
        ShelfTransitionCardView(configuration: configuration) {
            ShelfCrossfadeView(
                key: selectedGroup.id,
                value: GroupSnapshot(group: selectedGroup, selectedGrid: selectedGrid),
                configuration: configuration,
                shouldAnimate: { outgoing, incoming in
                    (outgoing.group.grids.count > 1) != (incoming.group.grids.count > 1)
                        || outgoing.selectedGrid.items.count != incoming.selectedGrid.items.count
                }
            ) { snapshot in
                VStack(spacing: 0) {
                    if snapshot.group.grids.count > 1 {
                        SegmentedControl(
                            segments: snapshot.group.grids.map {
                                .init(id: $0.id, title: $0.name)
                            },
                            initialSelection: snapshot.selectedGrid.id
                        ) { gridID in
                            selectedGridID = gridID
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    ShelfCrossfadeView(
                        key: "\(snapshot.group.id)|\(snapshot.selectedGrid.id)",
                        value: snapshot.selectedGrid,
                        configuration: configuration,
                        shouldAnimate: { outgoing, incoming in
                            outgoing.items.count != incoming.items.count
                        }
                    ) { grid in
                        AssetsGridRowsView(items: grid.items) { asset in
                            ServiceCardView(
                                config: .content(
                                    ServiceCardContent(
                                        title: asset.symbol,
                                        imageSource: .url(nil, chainIcon: nil),
                                        changeConfiguration: .content(
                                            text: asset.changeText,
                                            color: asset.changeColor
                                        )
                                    )
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private func selectGroup(_ group: PreviewGroup) {
        guard group.id != selectedGroupID else { return }
        selectedGroupID = group.id
        if !group.grids.contains(where: { $0.id == selectedGridID }) {
            selectedGridID = group.grids[0].id
        }
    }
}

#Preview("Shelf transition") {
    ShelfTransitionPreviewHarness()
        .debugPreview(background: .page)
        .tkThemed()
}
