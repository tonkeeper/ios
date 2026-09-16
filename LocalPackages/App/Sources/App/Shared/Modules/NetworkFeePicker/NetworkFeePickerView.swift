import SwiftUI
import TKUIKit

struct NetworkFeePickerView: View {
    @ObservedObject var viewModel: NetworkFeePickerViewModelImplementation
    var body: some View {
        categoriesSection
            .frame(maxWidth: .infinity, alignment: .top)
            .background(.backgroundPage)
    }
}

private extension NetworkFeePickerView {
    enum Layout {
        static let contentHorizontalInset: CGFloat = 16
        static let categoriesBottomInset: CGFloat = 16
    }

    @ViewBuilder
    var categoriesSection: some View {
        switch viewModel.viewState {
        case .list, .loading:
            // Uncategorized pickers have no segmented control, so the loading state shows only the
            // list skeleton (rendered by the view controller) — no category shimmer above it.
            EmptyView()
        case let .categories(categories, selectedCategoryID):
            SegmentedControl(
                segments: categories.map { category in
                    SegmentedControl<NetworkFeePickerCategory.ID>.Segment(
                        id: category.id,
                        title: category.title,
                        icon: category.icon.map {
                            .init(
                                image: $0,
                                size: 20
                            )
                        }
                    )
                },
                initialSelection: selectedCategoryID,
                onSelectionChange: viewModel.selectCategory
            )
            .padding(.horizontal, Layout.contentHorizontalInset)
            .padding(.bottom, Layout.categoriesBottomInset)
        }
    }
}

struct NetworkFeePickerItemRowView: View {
    let item: NetworkFeePickerItem
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        FeePickerCell(
            config: .content(item.feePickerCellContent),
            showsDivider: showsDivider,
            action: action
        )
        .frame(maxWidth: .infinity)
    }
}

struct NetworkFeePickerSkeletonRowView: View {
    let showsDivider: Bool

    var body: some View {
        FeePickerCell(
            config: .shimmer,
            showsDivider: showsDivider
        )
        .frame(maxWidth: .infinity)
    }
}

private extension NetworkFeePickerItem {
    var feePickerCellContent: FeePickerCellContent {
        FeePickerCellContent(
            leading: feePickerCellLeading,
            title: title,
            subtitle: subtitle,
            isDisabled: isDisabled,
            subtitleActionTitle: actionTitle,
            isSelected: isSelected
        )
    }

    var title: String {
        switch text {
        case let .singleLine(title), let .titled(title, _):
            title
        }
    }

    var subtitle: String? {
        switch text {
        case .singleLine:
            nil
        case let .titled(_, subtitle):
            subtitle
        }
    }

    var feePickerCellLeading: FeePickerCellContent.Leading {
        switch leading {
        case let .assetAvatar(imageSource):
            return .assetAvatar(imageSource: imageSource)
        case let .icon(image, tintColor, backgroundColor):
            return .icon(
                image: image,
                tintColor: tintColor,
                backgroundColor: backgroundColor
            )
        }
    }
}
