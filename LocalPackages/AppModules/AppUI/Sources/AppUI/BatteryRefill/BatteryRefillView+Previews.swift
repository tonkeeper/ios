import SwiftUI
import TKUIKit
import UIKit

private extension BatteryRefillViewActions {
    static let preview = BatteryRefillViewActions(
        selectPack: { _ in },
        choosePaymentMethod: {},
        confirm: {},
        openLink: { _ in },
        openSupportedTransactions: {},
        restorePurchases: {},
        close: {},
        endEditing: {}
    )
}

private extension BatteryRefillViewState {
    static let footer = "One charge covers the average transaction fee. Some transactions may cost more."
    static let description = "Pay network fees with charges on TON, TRON and EVM networks"
    static let paymentCaption = "A swap costs ≈ 50 charges, a transfer usually less. Fees vary by network."

    static let emptyAppStore = BatteryRefillViewState(
        header: Header(batteryState: .emptyTinted, charges: nil, description: description, warning: nil),
        showsTronBanner: true,
        packs: [
            Pack(id: "LargePack", title: "$17.99", caption: "2 363 charges", icon: .fill(1), tag: "Best value"),
            Pack(id: "MediumPack", title: "$11.99", caption: "1 576 charges", icon: .fill(0.5), isSelected: true),
            Pack(id: "SmallPack", title: "$5.99", caption: "788 charges", icon: .fill(0.3)),
        ],
        paymentMethod: PaymentMethod(id: "app_store", icon: .appStore, name: "App Store", caption: "Via App Store"),
        paymentCaption: paymentCaption,
        links: [.gift, .history],
        showsPromocode: true,
        footer: footer,
        mainButton: MainButton(title: "Pay with App Store", isEnabled: true),
        showsCloseButton: true
    )

    static let chargedCrypto = BatteryRefillViewState(
        header: Header(batteryState: .fill(0.75), charges: "371 charges", description: description, warning: nil),
        showsTronBanner: true,
        packs: [
            Pack(id: "large", title: "17.99 USD₮", caption: "2 500 charges", icon: .fill(1), tag: "Best value"),
            Pack(id: "medium", title: "11.99 USD₮", caption: "1 500 charges", icon: .fill(0.5), isSelected: true),
            Pack(id: "small", title: "5.99 USD₮", caption: "750 charges", icon: .fill(0.3)),
            Pack(id: "custom", title: "Other", caption: "Enter amount manually", icon: .other),
        ],
        paymentMethod: PaymentMethod(id: "usdt", icon: .url(nil), name: "USD₮", caption: "Balance 3 906 USD₮"),
        paymentCaption: paymentCaption,
        links: [.gift, .history],
        showsPromocode: true,
        footer: footer,
        mainButton: MainButton(title: "Top up for 11.99 USD₮", isEnabled: true),
        showsCloseButton: true
    )

    static let customCrypto: BatteryRefillViewState = {
        var state = chargedCrypto
        state.packs = state.packs.map {
            Pack(id: $0.id, title: $0.title, caption: $0.caption, icon: $0.icon, tag: $0.tag, isSelected: $0.id == "custom")
        }
        state.showsAmount = true
        state.mainButton = MainButton(title: "Top up for 1.2 USD₮", isEnabled: true)
        return state
    }()

    static let methods: [PaymentMethod] = [
        PaymentMethod(id: "usdt", icon: .url(nil), name: "USD₮", caption: "Balance 3 906 USD₮", isSelected: true),
        PaymentMethod(id: "ton", icon: .ton, name: "GRAM", caption: "Balance 2 345 GRAM"),
        PaymentMethod(id: "app_store", icon: .appStore, name: "App Store", caption: "Via App Store"),
    ] + otherTokens

    static let otherTokens: [PaymentMethod] = [
        otherToken("eth", "ETH", chain: ethereum, badge: nil, price: "$4 290.07", balance: "0.42", fiat: "$1 801.83"),
        otherToken("bnb", "BNB", chain: bsc, badge: nil, price: "$611.99", balance: "1.2", fiat: "$734.39"),
        otherToken("usdc", "USDC", chain: ethereum, badge: "ETHEREUM", price: "$1.00", balance: "250", fiat: "$250.00"),
        otherToken("usdc_base", "USDC", chain: base, badge: "BASE", price: "$1.00", balance: "120", fiat: "$120.00"),
        otherToken("shib", "SHIB", chain: ethereum, badge: "ETHEREUM", price: "$0.000012", balance: "500 000", fiat: "$6.00"),
    ]

    static let ethereum = PaymentMethod.Chain(id: "eth", title: "Ethereum", image: .TKUIKit.Icons.Size20.ethChain)
    static let bsc = PaymentMethod.Chain(id: "bsc", title: "BNB Chain", image: .TKUIKit.Icons.Size20.bscChain)
    static let base = PaymentMethod.Chain(id: "base", title: "Base", image: .TKUIKit.Icons.Size20.baseChain)

    static func otherToken(
        _ id: String,
        _ symbol: String,
        chain: PaymentMethod.Chain,
        badge: String?,
        price: String,
        balance: String,
        fiat: String
    ) -> PaymentMethod {
        PaymentMethod(
            id: id,
            icon: .url(nil),
            name: symbol,
            caption: "",
            otherToken: .init(
                chain: chain,
                row: AssetBalanceRowCellContent(
                    id: id,
                    title: symbol,
                    badge: badge,
                    displayMode: .includingDiffs(balance: balance, price: price, delta: nil, fiat: fiat, showsPin: false, priceColor: .textSecondary),
                    avatarImageSource: .url(nil)
                )
            )
        )
    }
}

private struct PromocodePlaceholder: View {
    var body: some View {
        Text("Promo Code")
            .textStyle(.body1)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 16)
            .background(.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AmountPlaceholder: View {
    @FocusState private var focus: Bool

    var body: some View {
        BatteryAmountField(
            placeholder: "Amount in USD₮",
            text: .constant("1.2"),
            caption: "≈ 1 158 charges · Available 3 906 USD₮",
            isValid: true,
            isFocused: $focus,
            accessibilityIdentifier: "battery_refill_amount"
        )
    }
}

#Preview("Empty · App Store") {
    BatteryRefillView(state: .emptyAppStore, actions: .preview) { EmptyView() } promocode: { PromocodePlaceholder() }
        .tkPreviewTheme(.deepBlue)
}

#Preview("75% · USD₮") {
    BatteryRefillView(state: .chargedCrypto, actions: .preview) { EmptyView() } promocode: { PromocodePlaceholder() }
        .tkPreviewTheme(.deepBlue)
}

#Preview("75% · USD₮ · Other") {
    BatteryRefillView(state: .customCrypto, actions: .preview) { AmountPlaceholder() } promocode: { PromocodePlaceholder() }
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Pay with", traits: .sizeThatFitsLayout) {
    BatteryPayWithView(methods: BatteryRefillViewState.methods, onSelect: { _ in })
        .padding(.top, 16)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Other tokens", traits: .fixedLayout(width: 390, height: 640)) {
    BatteryOtherTokensView(methods: BatteryRefillViewState.otherTokens, onSelect: { _ in })
        .padding(.top, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

private struct PayWithPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        PaymentPickerPreviewController(showsOtherTokens: false)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private struct OtherTokensPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        PaymentPickerPreviewController(showsOtherTokens: true)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class PaymentPickerPreviewController: UIViewController {
    private let showsOtherTokens: Bool

    init(showsOtherTokens: Bool) {
        self.showsOtherTokens = showsOtherTokens
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard presentedViewController == nil else { return }
        let header = TKBottomSheetHeaderConfiguration(
            title: .title(title: showsOtherTokens ? "Other tokens" : "Pay with"),
            leftButton: showsOtherTokens ? .init(content: .icon(.TKUIKit.Icons.Size16.chevronLeft), action: { _ in }) : nil,
            rightButton: showsOtherTokens ? nil : .close()
        )
        let content = TKBottomSheetScrollHostingController(header: header) {
            if showsOtherTokens {
                BatteryOtherTokensView(methods: BatteryRefillViewState.otherTokens, onSelect: { _ in })
            } else {
                BatteryPayWithView(methods: BatteryRefillViewState.methods, onSelect: { _ in })
            }
        }
        TKBottomSheetViewController(contentViewController: content).present(fromViewController: self)
    }
}

#Preview("Pay with · Sheet") {
    PayWithPreview().tkPreviewTheme(.deepBlue)
}

#Preview("Other tokens · Sheet") {
    OtherTokensPreview().tkPreviewTheme(.deepBlue)
}
