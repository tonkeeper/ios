import AppUI
import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

/// The asset a funding screen pays from or pays into.
public struct PerpsFundingAssetRow: Equatable {
    let assetId: String
    let symbol: String
    let network: PerpsFundingNetwork
    let iconURL: URL?
    /// "3 906 USDC · $3 902"; `nil` while the wallet's balance is unknown.
    let balanceText: String?

    public init(assetId: String = "", symbol: String, network: PerpsFundingNetwork, iconURL: URL?, balanceText: String?) {
        self.assetId = assetId
        self.symbol = symbol
        self.network = network
        self.iconURL = iconURL
        self.balanceText = balanceText
    }
}

/// The live quote under the asset: what lands on the Perps account and the fees on the way.
public enum PerpsFundingQuoteLine: Equatable {
    case fetching
    case quoted(received: String, fee: String?)
    case failed(String)
}

@MainActor
public protocol PerpsFundingAmountViewModeling: PerpsAmountFormLifecycle, ObservableObject {
    var titleText: String { get }
    var amountFocusState: PerpsAmountFocusState { get }
    var amountText: String { get }
    var amountPrefix: String { get }
    var amountSuffix: String? { get }
    /// The entry in the other unit; `nil` hides the pill under the amount.
    var counterpartText: String? { get }
    var canToggleUnit: Bool { get }
    var availableText: String? { get }
    var isBalanceLoading: Bool { get }
    var isAssetLoading: Bool { get }
    var isMaxEnabled: Bool { get }
    var canAddFunds: Bool { get }
    var isMaxPending: Bool { get }
    var asset: PerpsFundingAssetRow { get }
    var warningText: String? { get }
    var isReviewEnabled: Bool { get }
    var offersAnotherWallet: Bool { get }
    var isReviewInFlight: Bool { get }
    var quoteKey: String? { get }
    var quoteLine: PerpsFundingQuoteLine? { get }
    var showsActivationNote: Bool { get }
    var refusalKey: String? { get }

    func updateQuote() async
    func reportRefusal() async
    func setAmount(_ text: String)
    func toggleUnit()
    func setMax()
    func addFunds()
    func chooseAsset()
    func chooseAnotherWallet()
    func review()
    func close()
}

struct PerpsFundingAmountView<ViewModel: PerpsFundingAmountViewModeling>: View {
    @ObservedObject var viewModel: ViewModel
    @FocusState private var amountFocused: Bool
    /// With the keyboard up only what lands on the account fits above Review; the fees come with it down.
    @Environment(\.perpsKeyboardShown) private var isKeyboardShown

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    amountCard
                        .padding(.bottom, Layout.assetTopSpacing)
                    assetCell
                    quote
                }
                .padding(.horizontal, Layout.inset)
            }
            .tkImmediateButtonPresses()
            .dismissesKeyboardOnDrag()
            .task(id: viewModel.quoteKey) { await viewModel.updateQuote() }
            .task(id: viewModel.refusalKey) { await viewModel.reportRefusal() }
            warningLabel
            if viewModel.offersAnotherWallet {
                anotherWalletButton
            } else {
                reviewButton
            }
        }
        .background(.backgroundPage)
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = false }
        // A drag lowers the keypad unless it runs mostly sideways: that one can move the cursor in the amount.
        .simultaneousGesture(DragGesture().onChanged { drag in
            if amountFocused, abs(drag.translation.height) * 2 > abs(drag.translation.width) { amountFocused = false }
        })
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

    private var header: some View {
        ZStack {
            Text(viewModel.titleText)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
                .tkTextShimmer(isActive: viewModel.isBalanceLoading)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.titleInset)
            HStack {
                Spacer()
                PerpsCircleButton(icon: .TKUIKit.Icons.Size16.close, action: viewModel.close)
                    .accessibilityIdentifier("perps_funding_close")
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    private var amountCard: some View {
        AmountInputSheet(
            cardHeight: Layout.amountCardHeight,
            state: AmountInputSheetState(
                text: viewModel.amountText,
                placeholder: viewModel.isAssetLoading ? "" : "0",
                isTextLoading: viewModel.isMaxPending,
                prefix: viewModel.amountPrefix.isEmpty ? nil : viewModel.amountPrefix,
                symbol: viewModel.amountSuffix.flatMap { $0.isEmpty ? nil : .text($0) },
                converted: viewModel.counterpartText.map {
                    .init(
                        text: $0,
                        showsSwitchIcon: viewModel.canToggleUnit || viewModel.isBalanceLoading,
                        isSwitchEnabled: viewModel.canToggleUnit,
                        isTextLoading: viewModel.isBalanceLoading
                    )
                },
                balance: .init(
                    text: viewModel.availableText.map { "\(TKLocales.Perps.OpenPosition.balance) \($0)" } ?? "",
                    isLoading: viewModel.isBalanceLoading,
                    showsMax: true,
                    isMaxEnabled: viewModel.isMaxEnabled,
                    actionTitle: viewModel.canAddFunds ? TKLocales.WalletButtons.deposit : nil
                ),
                textFieldAccessibilityIdentifier: "perps_amount_input"
            ),
            focus: $amountFocused,
            onTextChange: viewModel.setAmount,
            onToggle: viewModel.toggleUnit,
            onMax: viewModel.setMax,
            onBalanceAction: viewModel.addFunds
        )
        .disabled(!viewModel.amountFocusState.isActive)
    }

    private var assetCell: some View {
        AssetPickerList(
            rows: [viewModel.isAssetLoading
                ? AssetPickerRowState(id: "asset", icon: .asset(.shimmer), title: "", subtitle: "", accessory: .switchIcon)
                : viewModel.asset.pickerRow(id: "asset", accessory: .switchIcon)],
            horizontalPadding: 0
        ) { _ in
            viewModel.chooseAsset()
        }
        .disabled(viewModel.isReviewInFlight)
    }

    @ViewBuilder private var quote: some View {
        switch viewModel.quoteLine {
        case nil:
            EmptyView()
        case .fetching:
            quoteCaption {
                CircularLoader(mode: .indeterminate, preset: .xSmall)
                    .frame(width: Layout.captionIconSize, height: Layout.captionIconSize)
                Text(TKLocales.Perps.DepositForm.fetchingQuote)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
        case let .failed(text):
            quoteCaption {
                Image(uiImage: .TKUIKit.Icons.Size16.exclamationMarkCircle)
                    .renderingMode(.template)
                    .foregroundStyle(.accentRed)
                Text(text)
                    .textStyle(.body2)
                    .foregroundStyle(.accentRed)
            }
        case let .quoted(received, fee):
            let showsFee = fee != nil && !isKeyboardShown
            VStack(spacing: 0) {
                PerpsFundingQuoteCells(cells: [
                    .init(title: TKLocales.Perps.Funding.toPerpsAccount, value: "≈ \(received)", accessibilityIdentifier: "perps_funding_received"),
                ] + (showsFee ? [.init(
                    title: TKLocales.Perps.Funding.fees,
                    value: "≈ \(fee ?? "")",
                    subtitle: viewModel.showsActivationNote ? TKLocales.Perps.DepositForm.accountSetupNote : nil,
                    accessibilityIdentifier: "perps_funding_fees"
                )] : []))
                if showsFee {
                    Text(TKLocales.Perps.DepositForm.noKeeperFee)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Layout.inset)
                        .padding(.top, Layout.footnoteTopPadding)
                        .padding(.bottom, Layout.inset)
                }
            }
            .padding(.top, Layout.cellsTopSpacing)
        }
    }

    private func quoteCaption(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Layout.captionSpacing, content: content)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Layout.captionMinHeight)
            .padding(.horizontal, Layout.inset)
            .padding(.vertical, Layout.captionVerticalPadding)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("perps_funding_quote")
    }

    @ViewBuilder private var warningLabel: some View {
        if let warningText = viewModel.warningText {
            Text(warningText)
                .textStyle(.body2)
                .foregroundStyle(.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.inset)
                .padding(.top, Layout.smallSpacing)
        }
    }

    private var reviewButton: some View {
        ButtonView(config: .init(
            title: TKLocales.Perps.OpenPosition.review,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            showsLoader: viewModel.isReviewInFlight,
            action: viewModel.review
        ))
        .disabled(!viewModel.isReviewEnabled)
        .padding(Layout.inset)
    }

    private var anotherWalletButton: some View {
        ButtonView(config: .init(
            title: TKLocales.Perps.DepositForm.chooseAnotherWallet,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            action: viewModel.chooseAnotherWallet
        ))
        .padding(Layout.inset)
        .accessibilityIdentifier("perps_funding_choose_another_wallet")
    }
}

extension PerpsFundingNetwork {
    init?(chainPrefix: String) {
        switch chainPrefix {
        case "ton": self = .ton
        case "eth": self = .ethereum
        case "base": self = .base
        case "arb": self = .arbitrum
        case "bsc": self = .bsc
        case "tron": self = .tron
        case "btc": self = .bitcoin
        case "sol": self = .sol
        case "polygon": self = .polygon
        case "avax": self = .avax
        case "robinhood": self = .robinhood
        default: return nil
        }
    }

    var chainIcon: UIImage {
        switch self {
        case .ton: .TKUIKit.Icons.Size20.tonChain
        case .ethereum: .TKUIKit.Icons.Size20.ethChain
        case .base: .TKUIKit.Icons.Size20.baseChain
        case .arbitrum: .TKUIKit.Icons.Size20.arbitrumChain
        case .bsc: .TKUIKit.Icons.Size20.bscChain
        case .tron: .TKUIKit.Icons.Size20.trxChain
        case .bitcoin: .TKUIKit.Icons.Size20.btcChain
        case .sol: .TKUIKit.Icons.Size20.solChain
        case .polygon: .TKUIKit.Icons.Size20.polygonChain
        case .avax: .TKUIKit.Icons.Size20.avalancheChain
        case .robinhood: .TKUIKit.Icons.Size20.robinhoodChain
        }
    }

    var displayName: String {
        switch self {
        case .ton: TKLocales.Receive.Multichain.Networks.Ton.displayTitle
        case .ethereum: TKLocales.Receive.Multichain.Networks.Ethereum.displayTitle
        case .base: TKLocales.Receive.Multichain.Networks.Base.displayTitle
        case .arbitrum: TKLocales.Receive.Multichain.Networks.Arbitrum.displayTitle
        case .bsc: TKLocales.Receive.Multichain.Networks.Smartchain.displayTitle
        case .tron: TKLocales.Receive.Multichain.Networks.Tron.displayTitle
        case .bitcoin: TKLocales.Receive.Multichain.Networks.Bitcoin.displayTitle
        case .sol: TKLocales.Receive.Multichain.Networks.Solana.displayTitle
        case .polygon: TKLocales.Receive.Multichain.Networks.Polygon.displayTitle
        case .avax: TKLocales.Receive.Multichain.Networks.Avalanche.displayTitle
        case .robinhood: TKLocales.Receive.Multichain.Networks.Robinhood.displayTitle
        }
    }
}

private extension View {
    /// A scroll lowers the keypad at once. Content that fits does not bounce, so it stays in place,
    /// and the screen's drag gesture lowers the keypad there, because no scroll starts.
    @ViewBuilder
    func dismissesKeyboardOnDrag() -> some View {
        if #available(iOS 16.4, *) {
            scrollDismissesKeyboard(.immediately)
                .scrollBounceBehavior(.basedOnSize)
        } else if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.immediately)
        } else {
            self
        }
    }
}

private enum Layout {
    static let inset: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let assetTopSpacing: CGFloat = 8
    /// Shorter than the shared card, as in the design, so the line under the asset fits with the keypad up.
    static let amountCardHeight: CGFloat = 156
    static let headerTopPadding: CGFloat = 18
    static let headerBottomPadding: CGFloat = 14
    static let titleInset: CGFloat = 48
    static let captionSpacing: CGFloat = 4
    static let captionIconSize: CGFloat = 16
    static let captionMinHeight: CGFloat = 24
    static let captionVerticalPadding: CGFloat = 12
    static let cellsTopSpacing: CGFloat = 16
    static let footnoteTopPadding: CGFloat = 12
}

/// Title-value cells in one rounded group, as in a confirmation, with an optional line under the title.
struct PerpsFundingQuoteCells: View {
    struct Cell {
        let title: String
        let value: String
        var subtitle: String? = nil
        let accessibilityIdentifier: String
    }

    let cells: [Cell]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.title) { index, cell in
                if index > 0 {
                    TKColor.separatorCommon
                        .frame(height: Self.separatorHeight)
                        .padding(.leading, Self.inset)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: Self.valueSpacing) {
                        Text(cell.title)
                            .textStyle(.body1)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                        Text(cell.value)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    }
                    if let subtitle = cell.subtitle {
                        Text(subtitle)
                            .textStyle(.body1)
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Self.inset)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(cell.accessibilityIdentifier)
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    private static let inset: CGFloat = 16
    private static let valueSpacing: CGFloat = 8
    private static let cornerRadius: CGFloat = 16
    private static let separatorHeight: CGFloat = 0.5
}
