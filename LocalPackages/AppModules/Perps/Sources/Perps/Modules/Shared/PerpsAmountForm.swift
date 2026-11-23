import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

public enum PerpsAmountFocusState: Equatable {
    case active(version: Int)
    case suppressed(version: Int)

    public var isActive: Bool {
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

    public func activated(requestFocus: Bool) -> PerpsAmountFocusState {
        .active(version: version + (requestFocus ? 1 : 0))
    }

    public func suppressingFocus() -> PerpsAmountFocusState {
        .suppressed(version: version + 1)
    }
}

public struct PerpsAmountFormBalanceRow {
    let balanceText: String?
    var errorText: String?
    let onMax: (() -> Void)?
    let onDeposit: (() -> Void)?
    let onRetry: (() -> Void)?

    public init(
        balanceText: String?,
        errorText: String? = nil,
        onMax: (() -> Void)?,
        onDeposit: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.balanceText = balanceText
        self.errorText = errorText
        self.onMax = onMax
        self.onDeposit = onDeposit
        self.onRetry = onRetry
    }
}

public struct PerpsAmountFormOptionRow: Identifiable {
    public let id: String
    let title: String
    let value: String
    let valueColor: TKColor
    let action: (() -> Void)?

    public init(id: String, title: String, value: String, valueColor: TKColor, action: (() -> Void)?) {
        self.id = id
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.action = action
    }
}

@MainActor
public protocol PerpsAmountFormLifecycle: AnyObject {
    func onAppear()
    func requestFocusOnAppear()
    func onDisappear()
}

@MainActor
public protocol PerpsAmountFormViewModel: PerpsAmountFormLifecycle, ObservableObject {
    var isLoading: Bool { get }
    var amountFocusState: PerpsAmountFocusState { get }
    var titleText: String { get }
    var priceTitle: String { get }
    var priceText: String { get }
    var showsPrice: Bool { get }
    var amountPrefix: String { get }
    var amountSuffix: String? { get }
    var isPriceTappable: Bool { get }
    var orderTypeSwitchText: String? { get }
    var amountText: String { get }
    var sizeTitle: String { get }
    /// nil hides the size subtitle (and its USD↔token toggle) under the input.
    var sizeText: String? { get }
    var balanceRow: PerpsAmountFormBalanceRow? { get }
    var optionRows: [PerpsAmountFormOptionRow] { get }
    var warningText: String? { get }
    var isReviewEnabled: Bool { get }

    func setAmount(_ text: String)
    func toggleSizeMode()
    func tapPrice()
    func tapOrderType()
    func review()
    func close()
}

extension PerpsAmountFormViewModel {
    var priceTitle: String {
        TKLocales.Perps.OpenPosition.price
    }

    var sizeTitle: String {
        TKLocales.Perps.OpenPosition.size
    }
}

/// Forms without a tappable price / order-type switcher render neither control,
/// so their taps are structurally unreachable.
public extension PerpsAmountFormViewModel {
    var showsPrice: Bool {
        true
    }

    var amountPrefix: String {
        "$"
    }

    var amountSuffix: String? {
        nil
    }

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
                    if viewModel.showsPrice {
                        headerPrice
                    }
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
        let label = Text("\(viewModel.priceTitle) \(viewModel.priceText)")
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
            focused: $amountFocused,
            prefix: viewModel.amountPrefix,
            suffix: viewModel.amountSuffix,
            suffixStyle: .num2,
            suffixSpacing: Layout.suffixSpacing
        ) {
            if let sizeText = viewModel.sizeText {
                Button(action: viewModel.toggleSizeMode) {
                    HStack(spacing: Layout.sizeIconSpacing) {
                        Text("\(viewModel.sizeTitle) \(sizeText)")
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
                if let onMax = balanceRow.onMax {
                    ButtonView(config: .init(
                        title: TKLocales.Perps.OpenPosition.max,
                        size: .small,
                        appearance: .secondary,
                        action: onMax
                    ))
                }
                Spacer()
                HStack(spacing: 4) {
                    if let errorText = balanceRow.errorText {
                        Text(errorText)
                            .textStyle(.body2)
                            .foregroundStyle(.accentRed)
                    } else if let balance = balanceRow.balanceText {
                        Text("\(TKLocales.Perps.OpenPosition.balance) \(balance)")
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                    }
                    if let onDeposit = balanceRow.onDeposit {
                        balanceLink(TKLocales.Perps.OpenPosition.deposit, in: balanceRow, action: onDeposit)
                    }
                    if let onRetry = balanceRow.onRetry {
                        balanceLink(TKLocales.Perps.Asset.retry, in: balanceRow, action: onRetry)
                    }
                }
            }
            .padding(.horizontal, Layout.inset)
        }
    }

    @ViewBuilder private func balanceLink(
        _ title: String,
        in balanceRow: PerpsAmountFormBalanceRow,
        action: @escaping () -> Void
    ) -> some View {
        if balanceRow.errorText != nil || balanceRow.balanceText != nil {
            Text("·")
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
        }
        Button(action: action) {
            Text(title)
                .textStyle(.body2)
                .foregroundStyle(.textAccent)
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
    static let suffixSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 8
    static let rowHeight: CGFloat = 56
}

/// Hosts an amount screen above the keyboard and gives its field focus on first appearance
/// and on returning from a pushed screen.
public final class PerpsAmountFormViewController<ViewModel: PerpsAmountFormLifecycle, Content: View>: UIViewController {
    private let viewModel: ViewModel
    private let keyboard: PerpsKeyboardOverlap
    /// The overlap of the latest keyboard frame; the content may still be on its way there.
    private var keyboardTarget: CGFloat = 0
    private let hostingController: TKHostingController<PerpsKeyboardAvoidingView<Content>>
    private var hasAppearedBefore = false

    init(viewModel: ViewModel, content: Content) {
        let keyboard = PerpsKeyboardOverlap()
        self.viewModel = viewModel
        self.keyboard = keyboard
        self.hostingController = TKHostingController(content: PerpsKeyboardAvoidingView(keyboard: keyboard, content: content))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
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
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    /// SwiftUI draws the final layout at once inside a frame that UIKit animates, so the Review button
    /// jumped ahead of the keyboard. The content moves by itself instead, on the keyboard's own curve.
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        var overlap: CGFloat = 0
        // A floating keyboard, or none under a full-screen frame, does not reach the screen's bottom and covers nothing.
        if let screen = view.window?.screen, frame.maxY >= screen.bounds.maxY {
            let keyboardTop = view.convert(frame, from: screen.coordinateSpace).minY
            overlap = max(0, view.bounds.maxY - keyboardTop - view.safeAreaInsets.bottom)
        }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let isAppearing = overlap > keyboard.height
        keyboardTarget = overlap
        let apply = { [weak self] in
            guard let self, keyboard.height != keyboardTarget else { return }
            withAnimation(duration > 0 ? PerpsKeyboardOverlap.animation : nil) {
                self.keyboard.height = self.keyboardTarget
            }
            // Starts the animation in this frame, together with the keyboard's.
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
        }
        // An appearing keyboard lays out its keys first and starts moving only when this run loop pass commits.
        if isAppearing {
            DispatchQueue.main.async(execute: apply)
        } else {
            apply()
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        viewModel.onAppear()
        if hasAppearedBefore, isReturningFromPushedController {
            viewModel.requestFocusOnAppear()
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppearedBefore {
            viewModel.requestFocusOnAppear()
        }
        hasAppearedBefore = true
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.onDisappear()
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

extension PerpsAmountFormViewController where ViewModel: PerpsAmountFormViewModel, Content == PerpsAmountFormView<ViewModel> {
    convenience init(viewModel: ViewModel) {
        self.init(viewModel: viewModel, content: PerpsAmountFormView(viewModel: viewModel))
    }
}

extension PerpsAmountFormViewController where ViewModel: PerpsFundingAmountViewModeling, Content == PerpsFundingAmountView<ViewModel> {
    convenience init(fundingViewModel viewModel: ViewModel) {
        self.init(viewModel: viewModel, content: PerpsFundingAmountView(viewModel: viewModel))
    }
}

@MainActor
final class PerpsKeyboardOverlap: ObservableObject {
    /// The keyboard's curve is a critically damped spring of this response.
    static var animation: Animation {
        .spring(response: 0.2, dampingFraction: 1)
    }

    @Published var height: CGFloat = 0
}

private struct PerpsKeyboardAvoidingView<Content: View>: View {
    @ObservedObject var keyboard: PerpsKeyboardOverlap
    let content: Content

    var body: some View {
        content
            .environment(\.perpsKeyboardShown, keyboard.height > 0)
            .padding(.bottom, keyboard.height)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

extension EnvironmentValues {
    /// Whether the keyboard covers the bottom of an amount screen, changed in the keyboard's animation.
    var perpsKeyboardShown: Bool {
        get { self[PerpsKeyboardShownKey.self] }
        set { self[PerpsKeyboardShownKey.self] = newValue }
    }
}

private struct PerpsKeyboardShownKey: EnvironmentKey {
    static let defaultValue = false
}
