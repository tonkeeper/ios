import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class ChartView: UIView {
    let chartView = UIKitChartCompatibilityView()
    let errorView = ChartErrorView()
    let separatorView = TKSeparatorView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: TKUIKit.ChartView.Model) {
        chartView.configure(model: model)
    }

    func configureHeader(configuration: ModernChartHeaderView.Configuration) {
        chartView.configureHeader(configuration: configuration)
    }

    private func setup() {
        addSubview(chartView)
        addSubview(errorView)
        addSubview(separatorView)

        errorView.isHidden = true

        setupConstraints()
    }

    private func setupConstraints() {
        chartView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        errorView.snp.makeConstraints { make in
            make.edges.equalTo(chartView)
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self)
        }
    }
}

final class UIKitChartCompatibilityView: UIView {
    var didSelectValue: ((Int) -> Void)? {
        didSet {
            interactionProxy.didSelectValue = didSelectValue
        }
    }

    var didDeselectValue: (() -> Void)? {
        didSet {
            interactionProxy.didDeselectValue = didDeselectValue
        }
    }

    var didStartDragging: (() -> Void)? {
        didSet {
            interactionProxy.didStartDragging = didStartDragging
        }
    }

    var didEndDragging: (() -> Void)? {
        didSet {
            interactionProxy.didEndDragging = didEndDragging
        }
    }

    private let headerStore = ModernChartHeaderView.ConfigurationStore(
        configuration: .shimmer
    )
    private let modelStore = ChartModelStore()
    private let interactionProxy = ChartInteractionProxy()
    private lazy var hostingController = TKHostingController(
        content: HostedChartRootView(
            headerStore: headerStore,
            modelStore: modelStore,
            interactionProxy: interactionProxy
        )
    )

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Layout.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: TKUIKit.ChartView.Model) {
        modelStore.model = model
        invalidateHostedLayout()
    }

    func configureHeader(configuration: ModernChartHeaderView.Configuration) {
        headerStore.configuration = configuration
        invalidateHostedLayout()
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        CGSize(width: targetSize.width, height: Layout.height)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        CGSize(width: targetSize.width, height: Layout.height)
    }

    private func setup() {
        backgroundColor = .clear

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        hostingController.view.backgroundColor = .clear

        addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        interactionProxy.didSelectValue = didSelectValue
        interactionProxy.didDeselectValue = didDeselectValue
        interactionProxy.didStartDragging = didStartDragging
        interactionProxy.didEndDragging = didEndDragging
    }

    private func invalidateHostedLayout() {
        setNeedsLayout()
    }
}

private extension UIKitChartCompatibilityView {
    enum Layout {
        static let height = TKUIKit.ChartView.height(showsBottomButtons: true)
    }
}

@MainActor
private final class ChartModelStore: ObservableObject {
    @Published var model: TKUIKit.ChartView.Model?
}

@MainActor
private final class ChartInteractionProxy {
    var didSelectValue: ((Int) -> Void)?
    var didDeselectValue: (() -> Void)?
    var didStartDragging: (() -> Void)?
    var didEndDragging: (() -> Void)?

    var interaction: TKUIKit.ChartView.Scenario {
        .interactive(
            .init(
                didSelectValue: { [weak self] index in
                    self?.didSelectValue?(index)
                },
                didDeselectValue: { [weak self] in
                    self?.didDeselectValue?()
                },
                didStartDragging: { [weak self] in
                    self?.didStartDragging?()
                },
                didEndDragging: { [weak self] in
                    self?.didEndDragging?()
                }
            )
        )
    }
}

@MainActor
private struct HostedChartRootView: View {
    @ObservedObject var headerStore: ModernChartHeaderView.ConfigurationStore
    @ObservedObject var modelStore: ChartModelStore
    let interactionProxy: ChartInteractionProxy

    var body: some View {
        Group {
            if let model = modelStore.model {
                TKUIKit.ChartView(
                    config: .init(
                        header: headerStore.configuration,
                        model: model
                    ),
                    scenario: interactionProxy.interaction
                )
            }
        }
    }
}

final class TokenChartViewState: ObservableObject {
    @Published private(set) var header: ChartHeaderView.Configuration = .shimmer
    @Published private(set) var model: TKUIKit.ChartView.Model?
    @Published private(set) var errorModel: ChartErrorView.Model?

    private let viewModel: ChartViewModel
    private var didLoad = false

    init(viewModel: ChartViewModel) {
        self.viewModel = viewModel
        setupBindings()
    }

    func loadIfNeeded() {
        guard !didLoad else {
            return
        }

        didLoad = true
        viewModel.viewDidLoad()
    }

    func didSelectChartPoint(at index: Int) {
        viewModel.didSelectChartPoint(at: index)
    }

    func didDeselectChartPoint() {
        viewModel.didDeselectChartPoint()
    }
}

private extension TokenChartViewState {
    func setupBindings() {
        viewModel.didUpdateChartData = { [weak self] model in
            self?.model = model
            self?.errorModel = nil
        }

        viewModel.didUpdateHeader = { [weak self] header in
            self?.header = header
        }

        viewModel.didFailedUpdateChartData = { [weak self] model in
            self?.errorModel = model
        }
    }
}

struct TokenChartView: View {
    @ObservedObject private var state: TokenChartViewState
    init(state: TokenChartViewState) {
        self.state = state
    }

    var body: some View {
        content
            .overlay {
                VStack {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(.separatorCommon)
                        .frame(height: TKUIKit.Constants.separatorWidth)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(
                height: TKUIKit.ChartView.height(
                    showsBottomButtons: true
                )
            )
            .background(Color.clear)
            .onAppear {
                state.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let errorModel = state.errorModel {
            VStack(spacing: 0) {
                ChartErrorContentView(
                    title: errorModel.title
                )

                if let buttons = errorModel.buttons {
                    ChartBottomButtonsView(config: buttons)
                }
            }
        } else if let model = state.model {
            TKUIKit.ChartView(
                config: .init(
                    header: state.header,
                    model: model
                ),
                scenario: chartScenario
            )
        } else {
            Color.clear
        }
    }

    private var chartScenario: TKUIKit.ChartView.Scenario {
        .interactive(
            .init(
                didSelectValue: { index in
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    state.didSelectChartPoint(at: index)
                },
                didDeselectValue: {
                    state.didDeselectChartPoint()
                }
            )
        )
    }
}
