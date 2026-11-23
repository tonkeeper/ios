import SwiftUI
import TKLocalize
import TKUIKit

public struct BatteryRefillView<Amount: View, Promocode: View>: View {
    private let state: BatteryRefillViewState
    private let actions: BatteryRefillViewActions
    private let amount: Amount
    private let promocode: Promocode

    public init(
        state: BatteryRefillViewState,
        actions: BatteryRefillViewActions,
        @ViewBuilder amount: () -> Amount,
        @ViewBuilder promocode: () -> Promocode
    ) {
        self.state = state
        self.actions = actions
        self.amount = amount()
        self.promocode = promocode()
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let header = state.header {
                    BatteryRefillHeaderView(
                        header: header,
                        onSupportedTransactionsTap: actions.openSupportedTransactions
                    )
                    .padding(.bottom, Layout.headerBottomPadding)
                }

                if state.showsTronBanner {
                    BatteryRefillTronBannerView()
                        .padding(.bottom, Layout.sectionSpacing)
                }

                if !state.packs.isEmpty {
                    packsSection
                        .padding(.bottom, Layout.sectionSpacing)
                }

                if state.showsAmount {
                    amount
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.groupSpacing)
                }

                if let paymentMethod = state.paymentMethod {
                    BatteryPaymentMethodCell(
                        method: paymentMethod,
                        title: TKLocales.Battery.Refill.payWith(paymentMethod.name),
                        trailing: .chevron,
                        action: actions.choosePaymentMethod
                    )
                    .accessibilityIdentifier("battery_pay_with")
                    .asCellsGroup()
                    .padding(.bottom, state.paymentCaption == nil ? Layout.groupSpacing : Layout.captionSpacing)
                }

                if let paymentCaption = state.paymentCaption {
                    Text(paymentCaption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.groupSpacing)
                }

                if !state.links.isEmpty {
                    linksSection
                        .padding(.bottom, Layout.sectionSpacing)
                }

                if state.showsPromocode {
                    promocode
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.sectionSpacing)
                }

                BatteryRefillFooterView(
                    description: state.footer,
                    onRestoreTap: actions.restorePurchases
                )
            }
            .padding(.bottom, Layout.listBottomPadding)
        }
        .tkImmediateButtonPresses()
        .tkDismissesKeyboardInteractively()
        .tkAdditionalKeyboardPadding(Layout.keyboardAdditionalPadding)
        .onTapGesture(perform: actions.endEditing)
        // Under liquid glass the header hands its buttons to the navigation bar and takes no height,
        // so the inset follows whichever of them draws the header.
        .safeAreaInset(edge: .top, spacing: 0) {
            DefaultModalCardHeader(config: headerConfig)
                .fixedSize(horizontal: false, vertical: true)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let mainButton = state.mainButton {
                actionBar(mainButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension BatteryRefillView {
    var headerConfig: DefaultModalCardHeader.Config {
        DefaultModalCardHeader.Config(
            rightIcon: state.showsCloseButton
                ? .close(accessibilityIdentifier: "battery_refill_close") { _ in actions.close() }
                : nil,
            height: .atLeast(Layout.navigationHeaderHeight),
            background: .scrim
        )
    }

    var packsSection: some View {
        BatteryPacksView(packs: state.packs, onSelect: actions.selectPack)
    }

    var linksSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.links.enumerated()), id: \.element.id) { index, link in
                BatteryLinkCell(
                    link: link,
                    showsDivider: index < state.links.count - 1,
                    action: { actions.openLink(link) }
                )
            }
        }
        .asCellsGroup()
    }

    func actionBar(_ mainButton: BatteryRefillViewState.MainButton) -> some View {
        ButtonView(
            config: ButtonView.Config(
                title: mainButton.title,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                showsLoader: mainButton.isLoading,
                action: actions.confirm
            )
        )
        .disabled(!mainButton.isEnabled || mainButton.isLoading)
        .accessibilityIdentifier("battery_refill_confirm")
        .padding(Layout.actionBarPadding)
        .tkScrim(.backgroundPage, edge: .bottom)
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let headerBottomPadding: CGFloat = 32
    static let sectionSpacing: CGFloat = 16
    static let groupSpacing: CGFloat = 32
    static let captionSpacing: CGFloat = 12
    static let listBottomPadding: CGFloat = 14
    static let navigationHeaderHeight: CGFloat = 64
    /// Keeps the line under the amount field above the action bar too: its 12 pt gap, a line and 16 pt.
    static let keyboardAdditionalPadding: CGFloat = 48
    static let actionBarPadding: CGFloat = 16
}

private struct BatteryRefillHeaderView: View {
    let header: BatteryRefillViewState.Header
    let onSupportedTransactionsTap: () -> Void

    var body: some View {
        VStack(spacing: Layout.batterySpacing) {
            BatterySwiftUIView(
                config: BatterySwiftUIViewConfig(
                    size: .size128,
                    state: header.batteryState
                )
            )

            VStack(spacing: Layout.textSpacing) {
                Text(TKLocales.Battery.Refill.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                if let charges = header.charges {
                    Text(charges)
                        .textStyle(.body1)
                        .foregroundStyle(.textSecondary)
                }

                Text(header.description)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let warning = header.warning {
                    Text(warning)
                        .textStyle(.body1)
                        .foregroundStyle(.accentRed)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onSupportedTransactionsTap) {
                    Text(TKLocales.Battery.Refill.supportedTransactions)
                        .textStyle(.body1)
                        .foregroundStyle(.accentBlue)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                .accessibilityIdentifier("battery_supported_transactions")
            }
            .padding(.horizontal, Layout.textHorizontalPadding)
        }
        .frame(maxWidth: .infinity)
    }

    private enum Layout {
        static let batterySpacing: CGFloat = 16
        static let textSpacing: CGFloat = 4
        static let textHorizontalPadding: CGFloat = 24
    }
}

private struct BatteryRefillTronBannerView: View {
    var body: some View {
        Cell(
            config: Cell.Config(),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: .image(.TKUIKit.Icons.Size44.batteryBanner),
                        shape: .rectangle(cornerRadius: Layout.iconCornerRadius)
                    )
                }
            },
            center: {
                CellCenter {
                    Text(TKLocales.Battery.Refill.TronBanner.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    Text(TKLocales.Battery.Refill.TronBanner.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            }
        )
        .asCellsGroup()
        .accessibilityIdentifier("battery_tron_banner")
    }

    private enum Layout {
        static let iconCornerRadius: CGFloat = 14
    }
}

/// The packs card, shared by the Battery screen and the Charge screen.
public struct BatteryPacksView: View {
    private let packs: [BatteryRefillViewState.Pack]
    private let onSelect: (String) -> Void

    public init(packs: [BatteryRefillViewState.Pack], onSelect: @escaping (String) -> Void) {
        self.packs = packs
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
                BatteryPackCell(
                    pack: pack,
                    showsDivider: index < packs.count - 1,
                    action: { onSelect(pack.id) }
                )
            }
        }
        .asCellsGroup()
    }
}

private struct BatteryPackCell: View {
    let pack: BatteryRefillViewState.Pack
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider, action: pack.isEnabled ? action : nil),
            leading: {
                // The design puts the narrow battery at the cell edge, not centered in a 44 pt asset slot.
                BatterySwiftUIView(
                    config: BatterySwiftUIViewConfig(size: .size44, state: batteryState, padding: Layout.batteryPadding)
                )
            },
            center: {
                CellCenter {
                    HStack(spacing: Layout.tagSpacing) {
                        Text(pack.title)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                        if let tag = pack.tag {
                            TKTagSwiftUIView(config: .accentTag(text: tag, accent: .accentBlue))
                        }
                    }
                } secondaryRow: {
                    Text(pack.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            },
            trailing: {
                if pack.isSelected {
                    BatteryCheckmarkAccessory()
                }
            }
        )
        .opacity(pack.isEnabled ? 1 : Layout.disabledOpacity)
        .accessibilityIdentifier("battery_pack_\(pack.id)")
    }

    private var batteryState: BatterySwiftUIViewConfig.State {
        switch pack.icon {
        case let .fill(percent): .fill(percent)
        case .other: .emptyGreen
        }
    }

    private enum Layout {
        static let tagSpacing: CGFloat = 6
        static let disabledOpacity: Double = 0.48
        static let batteryPadding = BatterySwiftUIViewConfig.Padding(top: 16, leading: 16, bottom: 16)
    }
}

struct BatteryPaymentMethodCell: View {
    enum Trailing {
        case chevron
        case checkmark
        case none
    }

    let method: BatteryRefillViewState.PaymentMethod
    let title: String
    let trailing: Trailing
    var showsDivider = false
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider, action: action),
            leading: {
                CellAssetLeading {
                    icon
                }
            },
            center: {
                CellCenter {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                } secondaryRow: {
                    Text(method.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            },
            trailing: {
                switch trailing {
                case .chevron:
                    BatteryChevronAccessory()
                case .checkmark:
                    BatteryCheckmarkAccessory()
                case .none:
                    EmptyView()
                }
            }
        )
    }

    @ViewBuilder
    private var icon: some View {
        switch method.icon {
        case let .asset(source):
            AssetAvatarView(imageSource: source)
        case .appStore:
            Circle()
                .fill(.constantWhite)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .overlay(
                    Image(systemName: "applelogo")
                        .font(.system(size: Layout.appleLogoSize, weight: .medium))
                        .foregroundStyle(.constantBlack)
                )
        case .ton:
            AssetAvatarView(imageSource: .image(.TKUIKit.Icons.Size44.tonLogo))
        case let .url(url):
            AssetAvatarView(imageSource: .url(url))
        }
    }

    private enum Layout {
        static let iconSize: CGFloat = 44
        static let appleLogoSize: CGFloat = 22
    }
}

private struct BatteryLinkCell: View {
    let link: BatteryRefillViewState.Link
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider, action: action),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: .image(image),
                        shape: .rectangle(cornerRadius: Layout.iconCornerRadius)
                    )
                }
            },
            center: {
                CellCenter {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    Text(caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            },
            trailing: {
                BatteryChevronAccessory()
            }
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var image: UIImage {
        switch link {
        case .gift: .TKUIKit.Icons.Size44.gift
        case .history: .TKUIKit.Icons.Size44.clock
        }
    }

    private var title: String {
        switch link {
        case .gift: TKLocales.Battery.Refill.Gift.title
        case .history: TKLocales.Battery.Refill.ChargesHistory.title
        }
    }

    private var caption: String {
        switch link {
        case .gift: TKLocales.Battery.Refill.Gift.caption
        case .history: TKLocales.Battery.Refill.ChargesHistory.caption
        }
    }

    private var accessibilityIdentifier: String {
        switch link {
        case .gift: "battery_gift"
        case .history: "battery_charges_history"
        }
    }

    private enum Layout {
        static let iconCornerRadius: CGFloat = 14
    }
}

private struct BatteryRefillFooterView: View {
    let description: String
    let onRestoreTap: () -> Void

    var body: some View {
        Text(attributedText)
            .textStyle(.body2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .tint(.textSecondary)
            .environment(\.openURL, OpenURLAction { _ in
                onRestoreTap()
                return .handled
            })
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalPadding)
            .accessibilityIdentifier("battery_restore_purchases")
    }

    private var attributedText: AttributedString {
        var text = AttributedString(description + " ")
        text.foregroundColor = TKColor.textTertiary.resolve(palette)
        var restore = AttributedString(TKLocales.Battery.Refill.Footer.restorePurchase)
        restore.link = Layout.restoreURL
        restore.foregroundColor = TKColor.textSecondary.resolve(palette)
        text.append(restore)
        return text
    }

    @Environment(\.tkPalette) private var palette

    private enum Layout {
        static let horizontalPadding: CGFloat = 32
        static let restoreURL = URL(string: "keeper-battery://restore-purchases")
    }
}

struct BatteryChevronAccessory: View {
    var body: some View {
        CellTrailingAccessory(
            config: CellTrailingAccessory.Config(
                color: .iconTertiary,
                icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                iconSize: 16
            )
        )
    }
}

struct BatteryCheckmarkAccessory: View {
    var body: some View {
        CellTrailingAccessory(
            config: CellTrailingAccessory.Config(
                color: .accentBlue,
                icon: SwiftUI.Image.TKUIKit.Icons.Size28.donemarkOutline
            )
        )
    }
}
