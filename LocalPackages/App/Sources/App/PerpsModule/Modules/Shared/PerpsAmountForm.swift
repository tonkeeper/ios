import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

enum PerpsAmountFocusState: Equatable {
    case active(version: Int)
    case suppressed(version: Int)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    private var version: Int {
        switch self {
        case let .active(version),
             let .suppressed(version):
            return version
        }
    }

    func activated(requestFocus: Bool) -> PerpsAmountFocusState {
        .active(version: version + (requestFocus ? 1 : 0))
    }

    func suppressingFocus() -> PerpsAmountFocusState {
        .suppressed(version: version + 1)
    }
}

struct PerpsAmountFormBalanceRow {
    let balanceText: String?
    let onMax: () -> Void
    let onDeposit: () -> Void
}

struct PerpsAmountFormOptionRow: Identifiable {
    let id: String
    let title: String
    let value: String
    let valueColor: TKColor
    let action: (() -> Void)?
}

@MainActor
protocol PerpsAmountFormViewModel: ObservableObject {
    var isLoading: Bool { get }
    var amountFocusState: PerpsAmountFocusState { get }
    var titleText: String { get }
    var priceText: String { get }
    var isPriceTappable: Bool { get }
    var orderTypeSwitchText: String? { get }
    var amountText: String { get }
    /// nil hides the size subtitle (and its USD↔token toggle) under the input.
    var sizeText: String? { get }
    var balanceRow: PerpsAmountFormBalanceRow? { get }
    var optionRows: [PerpsAmountFormOptionRow] { get }
    var warningText: String? { get }
    var isReviewEnabled: Bool { get }

    func onAppear()
    func requestFocusOnAppear()
    func setAmount(_ text: String)
    func toggleSizeMode()
    func tapPrice()
    func tapOrderType()
    func review()
    func close()
}

/// Forms without a tappable price / order-type switcher render neither control,
/// so their taps are structurally unreachable.
extension PerpsAmountFormViewModel {
    func tapPrice() {}
    func tapOrderType() {}
}

struct PerpsAmountFormView<ViewModel: PerpsAmountFormViewModel>: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: ViewModel
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isLoading {
                Spacer()
                CircularLoader(mode: .indeterminate, preset: .medium)
                Spacer()
            } else {
                form
            }
        }
        .background(.backgroundPage)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.amountFocusState) { state in
            guard state.isActive else {
                amountFocused = false
                return
            }
            DispatchQueue.main.async {
                guard viewModel.amountFocusState == state, state.isActive else { return }
                amountFocused = true
            }
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Layout.blockSpacing) {
                    amountCard
                    balanceRow
                    optionsCard
                    warningLabel
                }
                .padding(.top, Layout.blockSpacing)
            }
            .tkImmediateButtonPresses()
            reviewButton
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            VStack(spacing: -1) {
                Text(viewModel.titleText)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                HStack(spacing: 2) {
                    headerPrice
                    if let orderTypeText = viewModel.orderTypeSwitchText {
                        Text("·")
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                        Button(action: viewModel.tapOrderType) {
                            HStack(spacing: 2) {
                                Text(orderTypeText)
                                    .textStyle(.body2)
                                    .foregroundStyle(.textAccent)
                                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.textAccent)
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                PerpsCircleButton(icon: .TKUIKit.Icons.Size16.close, action: viewModel.close)
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    @ViewBuilder private var headerPrice: some View {
        let label = Text("\(TKLocales.Perps.OpenPosition.price) \(viewModel.priceText)")
            .textStyle(.body2)
            .foregroundStyle(.textSecondary)
        if viewModel.isPriceTappable {
            Button(action: viewModel.tapPrice) { label }
        } else {
            label
        }
    }

    // MARK: Amount

    private var amountCard: some View {
        PerpsAmountField(
            text: Binding(get: { viewModel.amountText }, set: { viewModel.setAmount($0) }),
            focused: $amountFocused
        ) {
            if let sizeText = viewModel.sizeText {
                Button(action: viewModel.toggleSizeMode) {
                    HStack(spacing: Layout.sizeIconSpacing) {
                        Text("\(TKLocales.Perps.OpenPosition.size) \(sizeText)")
                            .textStyle(.body1)
                            .foregroundStyle(.textSecondary)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.swapVertical)
                            .renderingMode(.template)
                            .foregroundStyle(.iconSecondary)
                    }
                    .padding(.vertical, -2)
                }
            }
        }
        .disabled(!viewModel.amountFocusState.isActive)
        .padding(.horizontal, Layout.inset)
    }

    @ViewBuilder private var balanceRow: some View {
        if let balanceRow = viewModel.balanceRow {
            HStack {
                ButtonView(config: .init(
                    title: TKLocales.Perps.OpenPosition.max,
                    size: .small,
                    appearance: .secondary,
                    action: balanceRow.onMax
                ))
                Spacer()
                HStack(spacing: 4) {
                    if let balance = balanceRow.balanceText {
                        Text("\(TKLocales.Perps.OpenPosition.balance) \(balance)")
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                        Text("·")
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                    }
                    Button(action: balanceRow.onDeposit) {
                        Text(TKLocales.Perps.OpenPosition.deposit)
                            .textStyle(.body2)
                            .foregroundStyle(.textAccent)
                    }
                }
            }
            .padding(.horizontal, Layout.inset)
        }
    }

    // MARK: Options

    private var optionsCard: some View {
        VStack(spacing: 0) {
            let rows = viewModel.optionRows
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    Divider().overlay(palette.separator.common)
                        .padding(.leading, Layout.inset)
                }
                optionRow(row)
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .padding(.horizontal, Layout.inset)
    }

    @ViewBuilder private var warningLabel: some View {
        if let warningText = viewModel.warningText {
            Text(warningText)
                .textStyle(.body2)
                .foregroundStyle(.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.inset)
                .padding(.top, -2)
        }
    }

    @ViewBuilder private func optionRow(_ row: PerpsAmountFormOptionRow) -> some View {
        let content = HStack(spacing: Layout.rowSpacing) {
            Text(row.title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(row.value)
                .textStyle(.label1)
                .foregroundStyle(row.valueColor)
            if row.action != nil {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .renderingMode(.template)
                    .foregroundStyle(.iconTertiary)
            }
        }
        .padding(.horizontal, Layout.inset)
        .frame(height: Layout.rowHeight)
        if let action = row.action {
            Button(action: action) { content }
        } else {
            content
        }
    }

    // MARK: Review

    private var reviewButton: some View {
        ButtonView(config: .init(
            title: TKLocales.Perps.OpenPosition.review,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            action: viewModel.review
        ))
        .disabled(!viewModel.isReviewEnabled)
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.blockSpacing)
    }
}

private enum Layout {
    static let inset: CGFloat = 16
    static let blockSpacing: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let headerTopPadding: CGFloat = 18
    static let headerBottomPadding: CGFloat = 14
    static let sizeIconSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 8
    static let rowHeight: CGFloat = 56
}

final class PerpsAmountFormViewController<ViewModel: PerpsAmountFormViewModel>: UIViewController {
    private let viewModel: ViewModel
    private let hostingController: TKHostingController<PerpsAmountFormView<ViewModel>>
    private var hasAppearedBefore = false

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        self.hostingController = TKHostingController(content: PerpsAmountFormView(viewModel: viewModel))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        if hasAppearedBefore, isReturningFromPushedController {
            viewModel.requestFocusOnAppear()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppearedBefore {
            viewModel.requestFocusOnAppear()
        }
        hasAppearedBefore = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            view.endEditing(true)
        }
    }

    private var isReturningFromPushedController: Bool {
        guard let coordinator = transitionCoordinator,
              coordinator.viewController(forKey: .to) === self,
              let fromViewController = coordinator.viewController(forKey: .from)
        else {
            return false
        }
        return fromViewController.navigationController === navigationController
    }
}
