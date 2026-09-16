import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct BatteryRechargeScreen: View {
    @ObservedObject var viewModel: BatteryRechargeViewModelImplementation
    let amountInputViewModel: AmountInputSwiftUIViewModel
    let promocodeViewModel: BatteryPromocodeInputViewModel
    let recipientViewModel: RecipientInputViewModel

    var body: some View {
        VStack(spacing: 0) {
            BatteryRechargeHeaderView(
                title: viewModel.title,
                tokenPickerState: viewModel.tokenPickerState,
                onTokenPickerTap: viewModel.openTokenPicker,
                onCloseTap: viewModel.close,
                onBackgroundTap: {
                    viewModel.endEditing?()
                }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.isGift {
                        RecipientInputView(viewModel: recipientViewModel)
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.bottom, Layout.sectionBottomPadding)
                    }

                    optionsSection
                        .padding(.bottom, Layout.sectionBottomPadding)

                    if viewModel.isCustomInputVisible {
                        AmountInputSwiftUIView(viewModel: amountInputViewModel)
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.bottom, Layout.sectionBottomPadding)
                    }

                    BatteryPromocodeInputView(viewModel: promocodeViewModel)
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.sectionBottomPadding)

                    continueButton
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.sectionBottomPadding)
                }
            }
            .tkImmediateButtonPresses()
            .tkDismissesKeyboardInteractively()
            .tkAdditionalKeyboardPadding(Layout.keyboardAdditionalPadding)
            .onTapGesture {
                viewModel.endEditing?()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension BatteryRechargeScreen {
    var optionsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.optionRows.enumerated()), id: \.element.id) { index, row in
                BatteryRechargeOptionCell(
                    row: row,
                    showsDivider: index < viewModel.optionRows.count - 1,
                    action: {
                        viewModel.selectOption(id: row.id)
                    }
                )
            }
        }
        .asCellsGroup()
    }

    var continueButton: some View {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.Actions.continueAction,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: viewModel.tapContinue
            )
        )
        .disabled(!viewModel.isContinueEnabled)
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionBottomPadding: CGFloat = 16
        static let keyboardAdditionalPadding: CGFloat = 32
    }
}

private struct BatteryRechargeHeaderView: View {
    let title: String
    let tokenPickerState: BatteryRechargeViewModelImplementation.TokenPickerState
    let onTokenPickerTap: () -> Void
    let onCloseTap: () -> Void
    let onBackgroundTap: () -> Void

    var body: some View {
        HStack(spacing: Layout.accessoriesSpacing) {
            Text(title)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            MultichainSwapTokenPickerCapsule(
                imageSource: tokenPickerImageSource,
                symbol: tokenPickerState.symbol,
                action: onTokenPickerTap
            )

            closeButton
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(minHeight: Layout.minHeight)
        .background(.backgroundPage)
        .contentShape(Rectangle())
        .onTapGesture(perform: onBackgroundTap)
    }

    private var tokenPickerImageSource: AssetAvatarViewImageSource {
        switch tokenPickerState.icon {
        case .ton:
            .image(.TKUIKit.Icons.Size44.tonLogo)
        case let .jetton(url):
            .url(url)
        }
    }

    private var closeButton: some View {
        Button(action: onCloseTap) {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.close)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.closeIconSize, height: Layout.closeIconSize)
                .foregroundStyle(.buttonSecondaryForeground)
                .padding(Layout.closeIconPadding)
                .background(.buttonSecondaryBackground)
                .clipShape(Circle())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let accessoriesSpacing: CGFloat = 12
        static let minHeight: CGFloat = 64
        static let closeIconSize: CGFloat = 16
        static let closeIconPadding: CGFloat = 8
    }
}

private struct BatteryRechargeOptionCell: View {
    let row: BatteryRechargeViewModelImplementation.OptionRow
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: showsDivider,
                action: row.isEnabled ? action : nil
            ),
            leading: {
                CellAssetLeading {
                    BatterySwiftUIView(
                        config: BatterySwiftUIViewConfig(
                            size: .size44,
                            state: row.batteryState
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
                RadioButtonView(isSelected: row.isSelected, size: Layout.radioButtonSize)
                    .opacity(row.isEnabled ? 1 : Layout.disabledRadioOpacity)
                    .accessibilityIdentifier("radio")
            }
        )
    }

    private enum Layout {
        static let radioButtonSize: CGFloat = 28
        static let disabledRadioOpacity: CGFloat = 0.48
    }
}
