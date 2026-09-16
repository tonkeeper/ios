import Foundation
import SwiftUI
import TKUIKit
import UIKit

@MainActor
protocol NetworkFeePickerDataSource {
    var content: NetworkFeePickerContent? { get }
    func loadContent() async -> NetworkFeePickerContent
}

@MainActor
protocol NetworkFeePickerItemsDataSource {
    var items: [NetworkFeePickerItem] { get }
}

@MainActor
protocol NetworkFeePickerModuleOutput: AnyObject {
    var didSelectItem: ((NetworkFeePickerItem, NetworkFeePickerCategory?) -> Void)? { get set }
    var didRequestClose: (() -> Void)? { get set }
}

@MainActor
protocol NetworkFeePickerModuleInput: AnyObject {}

struct NetworkFeePickerConfiguration {
    let title: String
    let subtitle: String?
    let skeletonItemCount: Int

    init(
        title: String,
        subtitle: String? = nil,
        skeletonItemCount: Int = 2
    ) {
        self.title = title
        self.subtitle = subtitle
        self.skeletonItemCount = skeletonItemCount
    }
}

enum NetworkFeePickerContent {
    case uncategorized(dataSource: any NetworkFeePickerItemsDataSource)
    case categorized(NetworkFeePickerCategoriesContent)
}

struct NetworkFeePickerCategoriesContent {
    let categories: [NetworkFeePickerCategory]
    let selectedCategoryID: NetworkFeePickerCategory.ID?
}

struct NetworkFeePickerCategory: Identifiable {
    let id: String
    let title: String
    let icon: UIImage?
    let dataSource: any NetworkFeePickerItemsDataSource
}

struct NetworkFeePickerItem: Identifiable {
    enum Leading {
        case assetAvatar(imageSource: AssetAvatarViewImageSource)
        case icon(
            image: UIImage,
            tintColor: TKColor,
            backgroundColor: TKColor
        )
    }

    enum Text {
        case singleLine(title: String)
        case titled(title: String, subtitle: String)
    }

    let id: String
    let leading: Leading
    let text: Text
    let isDisabled: Bool
    let actionTitle: String?
    let isSelected: Bool

    init(
        id: String,
        leading: Leading,
        text: Text,
        isDisabled: Bool = false,
        actionTitle: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.leading = leading
        self.text = text
        self.isDisabled = isDisabled
        self.actionTitle = actionTitle
        self.isSelected = isSelected
    }
}

enum NetworkFeePickerViewState {
    case loading
    case categories(
        [NetworkFeePickerCategory],
        selectedCategoryID: NetworkFeePickerCategory.ID
    )
    case list(
        NetworkFeePickerItemsDataSource
    )
}

@MainActor
final class NetworkFeePickerViewModelImplementation:
    ObservableObject,
    NetworkFeePickerModuleOutput,
    NetworkFeePickerModuleInput
{
    @Published private(set) var viewState: NetworkFeePickerViewState

    let configuration: NetworkFeePickerConfiguration

    var didSelectItem: ((NetworkFeePickerItem, NetworkFeePickerCategory?) -> Void)?
    var didRequestClose: (() -> Void)?

    private let dataSource: any NetworkFeePickerDataSource

    private var hasLoaded: Bool
    private var contentRequestID = 0
    private var contentTask: Task<Void, Never>?

    init(
        configuration: NetworkFeePickerConfiguration,
        dataSource: any NetworkFeePickerDataSource
    ) {
        self.configuration = configuration
        self.dataSource = dataSource
        let viewState: NetworkFeePickerViewState
        switch dataSource.content {
        case let .uncategorized(dataSource):
            viewState = .list(dataSource)
        case let .categorized(categories):
            if let firstCategory = categories.categories.first {
                let selectedCategoryId = categories.selectedCategoryID ?? firstCategory.id
                viewState = .categories(
                    categories.categories,
                    selectedCategoryID: selectedCategoryId
                )
            } else {
                viewState = .loading
            }
        case nil:
            viewState = .loading
        }
        switch viewState {
        case .loading:
            hasLoaded = false
        default:
            hasLoaded = true
        }
        self.viewState = viewState
    }

    deinit {
        contentTask?.cancel()
    }

    var modalHeaderConfiguration: TKBottomSheetHeaderConfiguration {
        TKBottomSheetHeaderConfiguration(
            title: .title(
                title: configuration.title,
                subtitle: configuration.subtitle
            ),
            rightButton: .close(),
            contentInsets: UIEdgeInsets(
                top: 16,
                left: 16,
                bottom: 16,
                right: 16
            )
        )
    }

    func viewDidLoad() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true
        reload()
    }

    func reload() {
        contentTask?.cancel()

        contentRequestID += 1
        let requestID = contentRequestID

        viewState = .loading

        contentTask = Task { [weak self] in
            guard let self else {
                return
            }

            let content = await dataSource.loadContent()
            guard !Task.isCancelled, requestID == contentRequestID else {
                return
            }

            apply(content: content)
        }
    }

    func selectCategory(_ categoryID: NetworkFeePickerCategory.ID) {
        guard
            case let .categories(categories, selectedCategoryID) = viewState,
            selectedCategoryID != categoryID,
            categories.map(\.id).contains(categoryID)
        else {
            return
        }
        viewState = .categories(
            categories,
            selectedCategoryID: categoryID
        )
    }

    func selectItem(_ item: NetworkFeePickerItem) {
        didSelectItem?(item, selectedCategory)
    }
}

private extension NetworkFeePickerViewModelImplementation {
    var selectedCategory: NetworkFeePickerCategory? {
        guard case let .categories(categories, selectedCategoryID) = viewState else {
            return nil
        }
        return categories.first(where: { $0.id == selectedCategoryID })
    }

    func apply(content: NetworkFeePickerContent) {
        switch content {
        case let .uncategorized(dataSource):
            viewState = .list(dataSource)
        case let .categorized(content):
            guard !content.categories.isEmpty else {
                viewState = .categories([], selectedCategoryID: "")
                return
            }
            let fallbackSelectedCategory = content.categories[0].id
            let selectedCategoryId = content
                .selectedCategoryID
                .flatMap {
                    content.categories
                        .map(\.id)
                        .contains($0) ? $0 : fallbackSelectedCategory
                } ?? fallbackSelectedCategory
            viewState = .categories(
                content.categories,
                selectedCategoryID: selectedCategoryId
            )
        }
    }
}
