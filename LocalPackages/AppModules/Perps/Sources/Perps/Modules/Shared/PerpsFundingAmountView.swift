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
    var availableText: String { get }
    var isMaxEnabled: Bool { get }
    var canAddFunds: Bool { get }
    var isMaxPending: Bool { get }
    var asset: PerpsFundingAssetRow { get }
    var warningText: String? { get }
    var isReviewEnabled: Bool { get }
    var isReviewInFlight: Bool { get }

    func setAmount(_ text: String)
    func toggleUnit()
    func setMax()
    func addFunds()
    func chooseAsset()
    func review()
    func close()
}

struct PerpsFundingAmountView<ViewModel: PerpsFundingAmountViewModeling>: View {
    @ObservedObject var viewModel: ViewModel
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    amountCard
                        .padding(.bottom, Layout.assetTopSpacing)
                    assetCell
                    warningLabel
                }
                .padding(.horizontal, Layout.inset)
            }
            .tkImmediateButtonPresses()
            reviewButton
        }
        .background(.backgroundPage)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
                .lineLimit(1)
                .padding(.horizontal, Layout.titleInset)
            HStack {
                Spacer()
                PerpsCircleButton(icon: .TKUIKit.Icons.Size16.close, action: viewModel.close)
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    private var amountCard: some View {
        AmountInputSheet(
            state: AmountInputSheetState(
                text: viewModel.amountText,
                isTextLoading: viewModel.isMaxPending,
                prefix: viewModel.amountPrefix.isEmpty ? nil : viewModel.amountPrefix,
                symbol: viewModel.amountSuffix.flatMap { $0.isEmpty ? nil : .text($0) },
                converted: viewModel.counterpartText.map {
                    .init(text: $0, showsSwitchIcon: viewModel.canToggleUnit, isSwitchEnabled: viewModel.canToggleUnit)
                },
                balance: .init(
                    text: "\(TKLocales.Perps.OpenPosition.balance) \(viewModel.availableText)",
                    showsMax: true,
                    isMaxEnabled: viewModel.isMaxEnabled,
                    actionTitle: viewModel.canAddFunds ? TKLocales.WalletButtons.deposit : nil
                )
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
            rows: [viewModel.asset.pickerRow(id: "asset", accessory: .switchIcon)],
            horizontalPadding: 0
        ) { _ in
            viewModel.chooseAsset()
        }
        .disabled(viewModel.isReviewInFlight)
    }

    @ViewBuilder private var warningLabel: some View {
        if let warningText = viewModel.warningText {
            Text(warningText)
                .textStyle(.body2)
                .foregroundStyle(.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
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
}

extension PerpsFundingNetwork {
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

private enum Layout {
    static let inset: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let assetTopSpacing: CGFloat = 8
    static let headerTopPadding: CGFloat = 18
    static let headerBottomPadding: CGFloat = 14
    static let titleInset: CGFloat = 48
}
