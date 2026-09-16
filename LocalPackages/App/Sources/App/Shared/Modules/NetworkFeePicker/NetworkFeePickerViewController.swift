import Combine
import SwiftUI
import TKUIKit
import UIKit

final class NetworkFeePickerViewController: GenericViewViewController<NetworkFeePickerUiView>, TKBottomSheetDynamicScrollContentViewController {
    private enum Layout {
        static let estimatedRowHeight: CGFloat = 76
    }

    private enum TableKey: Hashable {
        case loading
        case list
        case category(NetworkFeePickerCategory.ID)
    }

    private enum TableRow {
        case skeleton(Int)
        case item(NetworkFeePickerItem)
    }

    private final class TableContext {
        let tableView: UITableView
        var rows: [TableRow] = []

        init(tableView: UITableView) {
            self.tableView = tableView
        }
    }

    private let viewModel: NetworkFeePickerViewModelImplementation
    private var cancellables = Set<AnyCancellable>()
    private lazy var fallbackTableView = makeTableView()
    private var tableContexts = [TableKey: TableContext]()
    private weak var activeTableView: UITableView?

    var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        viewModel.modalHeaderConfiguration
    }

    var scrollView: UIScrollView {
        activeTableView ?? fallbackTableView
    }

    var didUpdateHeight: (() -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?
    var didUpdateScrollView: ((UIScrollView) -> Void)?

    init(viewModel: NetworkFeePickerViewModelImplementation) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupContent()
        bindViewModel()
        viewModel.viewDidLoad()
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        return customView.calculateHeight(width: width)
    }
}

private extension NetworkFeePickerViewController {
    func bindViewModel() {
        viewModel.$viewState
            .dropFirst()
            .sink { [weak self] viewState in
                self?.scheduleRender(viewState)
            }
            .store(in: &cancellables)
    }

    func setupContent() {
        customView.categoriesHostingView.setContent {
            NetworkFeePickerView(viewModel: viewModel)
        }
        render(viewState: viewModel.viewState)
    }

    func scheduleRender(_ viewState: NetworkFeePickerViewState) {
        DispatchQueue.main.async { [weak self] in
            self?.render(viewState: viewState)
        }
    }

    func render(viewState: NetworkFeePickerViewState) {
        let context = tableContext(for: viewState)
        let previousTableView = activeTableView

        activeTableView = context.tableView
        customView.setActiveScrollView(
            context.tableView,
            hasRows: !context.rows.isEmpty
        )

        context.tableView.reloadData()
        context.tableView.layoutIfNeeded()

        if previousTableView !== context.tableView {
            didUpdateScrollView?(context.tableView)
        }

        updateHeight()
    }

    func updateHeight() {
        customView.categoriesHostingView.invalidateIntrinsicContentSize()
        customView.setNeedsLayout()
        customView.layoutIfNeeded()
        didUpdateHeight?()
    }

    private func tableContext(for viewState: NetworkFeePickerViewState) -> TableContext {
        switch viewState {
        case .loading:
            return tableContext(
                key: .loading,
                rows: (0 ..< viewModel.configuration.skeletonItemCount).map(TableRow.skeleton)
            )
        case let .list(dataSource):
            return tableContext(
                key: .list,
                rows: dataSource.items.map(TableRow.item)
            )
        case let .categories(categories, selectedCategoryID):
            let rows = categories
                .first(where: { $0.id == selectedCategoryID })?
                .dataSource
                .items
                .map(TableRow.item) ?? []
            return tableContext(
                key: .category(selectedCategoryID),
                rows: rows
            )
        }
    }

    private func tableContext(
        key: TableKey,
        rows: [TableRow]
    ) -> TableContext {
        let context: TableContext
        if let existingContext = tableContexts[key] {
            context = existingContext
        } else {
            context = TableContext(
                tableView: makeTableView()
            )
            tableContexts[key] = context
        }

        context.rows = rows
        return context
    }

    func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Layout.estimatedRowHeight
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.sectionHeaderTopPadding = 0
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.register(
            SwiftUIHostingTableViewCell.self,
            forCellReuseIdentifier: String(describing: SwiftUIHostingTableViewCell.self)
        )
        tableView.dataSource = self
        return tableView
    }

    private func context(for tableView: UITableView) -> TableContext? {
        tableContexts.values.first { $0.tableView === tableView }
    }
}

extension NetworkFeePickerViewController: UITableViewDataSource {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        context(for: tableView)?.rows.count ?? 0
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let reuseIdentifier = String(describing: SwiftUIHostingTableViewCell.self)
        let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        )

        guard
            let hostingCell = cell as? SwiftUIHostingTableViewCell,
            let context = context(for: tableView),
            context.rows.indices.contains(indexPath.row)
        else {
            return cell
        }

        let rowsCount = context.rows.count
        let showsDivider = indexPath.row < rowsCount - 1
        hostingCell.applyGroupedBackground(
            .init(index: indexPath.row, count: rowsCount)
        )

        switch context.rows[indexPath.row] {
        case let .skeleton(index):
            hostingCell.setContent(id: "skeleton-\(index)") {
                NetworkFeePickerSkeletonRowView(showsDivider: showsDivider)
            }
        case let .item(item):
            hostingCell.setContent(id: item.id) { [weak viewModel] in
                NetworkFeePickerItemRowView(
                    item: item,
                    showsDivider: showsDivider,
                    action: { viewModel?.selectItem(item) }
                )
            }
        }

        return hostingCell
    }
}
