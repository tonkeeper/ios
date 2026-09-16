import SwiftUI
import TKUIKit

struct RampOnView: View {
    @ObservedObject var viewModel: RampOnViewModel

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    title: DefaultModalCardHeader.Title(
                        text: viewModel.screenTitle
                    ),
                    rightIcon: .close(
                        onTap: { _ in
                            viewModel.close()
                        }
                    ),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            content
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension RampOnView {
    var content: some View {
        VStack(spacing: 0) {
            actionRow

            if viewModel.isLayoutLoading {
                layoutShimmer
            } else if viewModel.showsLayoutError {
                layoutErrorPlaceholder
            } else {
                layoutRows
            }
        }
    }

    var actionRow: some View {
        Group {
            if case let .action(kind) = viewModel.actionItem {
                SetupCell(
                    content: kind.setupCellContent,
                    onTap: {
                        viewModel.select(item: viewModel.actionItem)
                    }
                )
            }
        }
        .asCellsGroup()
        .padding(.bottom, hasLayoutContentBelow ? 8 : 16)
    }

    var hasLayoutContentBelow: Bool {
        viewModel.isLayoutLoading || viewModel.showsLayoutError || !viewModel.layoutItems.isEmpty
    }

    var layoutShimmer: some View {
        RampOnLayoutShimmerCell()
            .asCellsGroup()
            .padding(.bottom, 16)
    }

    var layoutRows: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.layoutItems) { item in
                if case let .card(layoutCard) = item {
                    RampOnLayoutItemCell(
                        item: layoutCard,
                        onTap: {
                            viewModel.select(item: item)
                        }
                    )
                    .asCellsGroup()
                }
            }
        }
        .padding(.bottom, 16)
    }

    var layoutErrorPlaceholder: some View {
        RampOnLayoutLoadErrorCell {
            viewModel.retry()
        }
        .asCellsGroup()
        .padding(.bottom, 16)
    }
}
