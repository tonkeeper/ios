import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct BatteryRefillScreen: View {
    @ObservedObject var viewModel: BatteryRefillViewModelImplementation
    let promocodeViewModel: BatteryPromocodeInputViewModel

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let header = viewModel.header {
                        BatteryRefillHeaderView(
                            header: header,
                            onSupportedTransactionsTap: viewModel.openSupportedTransactions
                        )
                        .padding(.top, Layout.sectionTopPadding)
                        .padding(.bottom, Layout.sectionBottomPadding)
                    }

                    if viewModel.showsSettings {
                        settingsSection
                            .padding(.bottom, Layout.sectionBottomPadding)
                    }

                    if viewModel.showsRefillSections {
                        BatteryPromocodeInputView(viewModel: promocodeViewModel)
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.bottom, Layout.sectionBottomPadding)

                        if !viewModel.inAppPurchaseRows.isEmpty {
                            inAppPurchasesSection
                                .padding(.bottom, Layout.sectionBottomPadding)
                        }

                        if !viewModel.rechargeMethodRows.isEmpty {
                            rechargeMethodsSection
                                .padding(.bottom, Layout.sectionBottomPadding)
                        }
                    }

                    historySection
                        .padding(.bottom, Layout.sectionBottomPadding)

                    BatteryRefillFooterView(
                        description: viewModel.footerDescription,
                        onRestoreTap: viewModel.restorePurchases
                    )
                }
                .padding(.top, Layout.navigationHeaderHeight)
                .padding(.bottom, Layout.listBottomPadding)
            }
            .tkImmediateButtonPresses()
            .tkDismissesKeyboardInteractively()
            .tkAdditionalKeyboardPadding(Layout.keyboardAdditionalPadding)
            .onTapGesture {
                viewModel.endEditing?()
            }

            DefaultModalCardHeader(config: headerConfig)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension BatteryRefillScreen {
    var headerConfig: DefaultModalCardHeader.Config {
        DefaultModalCardHeader.Config(
            rightIcon: viewModel.showsCloseButton
                ? .close(accessibilityIdentifier: "battery_refill_close") { _ in viewModel.close() }
                : nil,
            height: .atLeast(Layout.navigationHeaderHeight),
            background: .scrim
        )
    }

    var settingsSection: some View {
        Cell(
            config: Cell.Config(action: viewModel.openSettings),
            center: {
                CellCenter {
                    Text(TKLocales.Battery.Refill.Settings.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    Text(TKLocales.Battery.Refill.Settings.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            },
            trailing: {
                BatteryRefillChevronAccessory()
            }
        )
        .asCellsGroup()
    }

    var inAppPurchasesSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.inAppPurchaseRows.enumerated()), id: \.element.id) { index, row in
                BatteryRefillInAppPurchaseCell(
                    row: row,
                    showsDivider: index < viewModel.inAppPurchaseRows.count - 1,
                    onBuyTap: {
                        viewModel.purchase(productIdentifier: row.id)
                    }
                )
            }
        }
        .asCellsGroup()
    }

    var rechargeMethodsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.rechargeMethodRows.enumerated()), id: \.element.id) { index, row in
                BatteryRefillRechargeMethodCell(
                    row: row,
                    showsDivider: index < viewModel.rechargeMethodRows.count - 1,
                    action: {
                        viewModel.selectRechargeMethod(id: row.id)
                    }
                )
            }
        }
        .asCellsGroup()
    }

    var historySection: some View {
        Cell(
            config: Cell.Config(action: viewModel.openHistory),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: .image(.TKUIKit.Icons.Size44.clock),
                        shape: .rectangle(cornerRadius: Layout.iconCornerRadius)
                    )
                }
            },
            center: {
                CellCenter {
                    Text(TKLocales.Battery.Refill.ChargesHistory.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    Text(TKLocales.Battery.Refill.ChargesHistory.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            },
            trailing: {
                BatteryRefillChevronAccessory()
            }
        )
        .accessibilityIdentifier("battery_charges_history")
        .asCellsGroup()
    }
}

private struct BatteryRefillHeaderView: View {
    let header: BatteryRefillViewModelImplementation.HeaderState
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
                if header.showsBetaTag {
                    TKTagSwiftUIView(config: .accentTag(text: "BETA", accent: .accentOrange))
                }

                Text(TKLocales.Battery.Refill.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .padding(.top, Layout.titleTopPadding)

                Text(header.caption)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Layout.subtitleTopPadding)

                if let warning = header.warning {
                    Text(warning)
                        .textStyle(.body2)
                        .foregroundStyle(.accentRed)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if header.showsSupportedTransactionsButton {
                    Button(action: onSupportedTransactionsTap) {
                        Text(TKLocales.Battery.Refill.supportedTransactions)
                            .textStyle(.body2)
                            .foregroundStyle(.accentBlue)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                }
            }
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
        }
        .frame(maxWidth: .infinity)
    }

    private enum Layout {
        static let batterySpacing: CGFloat = 16
        static let textSpacing: CGFloat = 1
        static let textHorizontalPadding: CGFloat = 32
        static let textBottomPadding: CGFloat = 16
        static let titleTopPadding: CGFloat = 9
        static let subtitleTopPadding: CGFloat = 6
    }
}

private struct BatteryRefillInAppPurchaseCell: View {
    let row: BatteryRefillViewModelImplementation.InAppPurchaseRow
    let showsDivider: Bool
    let onBuyTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider),
            leading: {
                CellAssetLeading {
                    BatterySwiftUIView(
                        config: BatterySwiftUIViewConfig(
                            size: .size44,
                            state: .fill(row.batteryPercent)
                        )
                    )
                }
            },
            center: {
                CellCenter {
                    Text(row.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    Text(row.caption)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            },
            trailing: {
                ButtonView(
                    config: ButtonView.Config(
                        title: row.buttonTitle,
                        size: .small,
                        appearance: .primary,
                        action: onBuyTap
                    )
                )
                .disabled(!row.isEnabled)
                .padding(.trailing, Layout.buttonTrailingPadding)
                .animation(Layout.buttonTitleAnimation, value: row.buttonTitle)
            }
        )
    }

    private enum Layout {
        static let buttonTrailingPadding: CGFloat = 16
        static let buttonTitleAnimation: Animation = .easeInOut(duration: 0.14)
    }
}

private struct BatteryRefillRechargeMethodCell: View {
    let row: BatteryRefillViewModelImplementation.RechargeMethodRow
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(showsDivider: showsDivider, action: action),
            leading: {
                CellAssetLeading {
                    iconView
                }
            },
            center: {
                CellCenter {
                    Text(row.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } secondaryRow: {
                    if let caption = row.caption {
                        Text(caption)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                    }
                }
            },
            trailing: {
                BatteryRefillChevronAccessory()
            }
        )
    }

    @ViewBuilder
    private var iconView: some View {
        switch row.icon {
        case .ton:
            AssetAvatarView(imageSource: .image(.TKUIKit.Icons.Size44.tonLogo))
        case let .jetton(url):
            AssetAvatarView(imageSource: .url(url))
        case .gift:
            AssetAvatarView(
                imageSource: .image(.TKUIKit.Icons.Size44.gift),
                shape: .rectangle(cornerRadius: BatteryRefillScreen.Layout.iconCornerRadius)
            )
        }
    }
}

private struct BatteryRefillFooterView: View {
    let description: String
    let onRestoreTap: () -> Void

    var body: some View {
        VStack(spacing: Layout.textSpacing) {
            Text(description)
                .textStyle(.body2)
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRestoreTap) {
                Text(TKLocales.Battery.Refill.Footer.restorePurchase)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.topPadding)
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 48
        static let topPadding: CGFloat = -1
        static let textSpacing: CGFloat = -3
    }
}

private struct BatteryRefillChevronAccessory: View {
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

private extension BatteryRefillScreen {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionTopPadding: CGFloat = 6
        static let sectionBottomPadding: CGFloat = 16
        static let listBottomPadding: CGFloat = 14
        static let navigationHeaderHeight: CGFloat = 64
        static let keyboardAdditionalPadding: CGFloat = 32
        static let iconCornerRadius: CGFloat = 12
    }
}
