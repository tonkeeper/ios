import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct MultichainSwapConfirmationView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: MultichainSwapConfirmationViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    amountSection
                    detailsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .tkImmediateButtonPresses()

            MultichainSwapConfirmationSliderRepresentable(
                title: confirmSliderTitle(for: viewModel.executionState),
                appearance: viewModel.priceImpactSeverity.sliderAppearance,
                isEnabled: viewModel.isConfirmEnabled,
                resetToken: viewModel.sliderResetToken,
                onConfirm: viewModel.confirmSwipe
            )
            .frame(height: 88)
            .padding(16)
        }
        .background(.backgroundPage)
    }

    private var headerView: some View {
        DefaultModalCardHeader(
            config: .init(
                leftIcon: .init(
                    image: .TKUIKit.Icons.Size16.chevronLeft,
                    size: 16,
                    padding: 8,
                    onTap: { _ in
                        viewModel.back()
                    }
                ),
                title: .init(
                    text: TKLocales.NativeSwap.Screen.Confirm.title
                ),
                rightIcon: .close { _ in
                    viewModel.close()
                }
            )
        )
    }

    private var amountSection: some View {
        let model = viewModel.display
        return VStack(spacing: 0) {
            MultichainSwapConfirmationAmountCard(
                label: TKLocales.NativeSwap.Field.send,
                amountLine: model.sendLine,
                tokenAvatarSource: model.sendTokenAvatarSource
            )

            Color.clear
                .frame(height: 8)
                .overlay(alignment: .trailing) {
                    swapDirectionArrow
                }
                .zIndex(1)

            MultichainSwapConfirmationAmountCard(
                label: TKLocales.NativeSwap.Field.receive,
                amountLine: model.receiveLine,
                tokenAvatarSource: model.receiveTokenAvatarSource
            )
        }
    }

    private var swapDirectionArrow: some View {
        SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size16.arrowDown)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(.buttonTertiaryForeground)
            .frame(width: 40, height: 40)
            .background(.buttonTertiaryBackground)
            .clipShape(Circle())
            .padding(.trailing, 28)
    }

    private func confirmSliderTitle(
        for state: MultichainSwapConfirmationExecutionState
    ) -> NSAttributedString {
        let title = NSMutableAttributedString()
        title.append(
            state.confirmTitle.withTextStyle(
                .label2,
                color: .Text.secondary,
                alignment: .center
            )
        )
        if !state.confirmSubtitle.isEmpty {
            title.append(
                ("\n" + state.confirmSubtitle).withTextStyle(
                    .body3,
                    color: .Text.tertiary,
                    alignment: .center
                )
            )
        }
        return title
    }

    private var detailsCard: some View {
        let model = viewModel.display
        let hasExecutionStatus = viewModel.executionState.statusLine != nil
        let priceImpactRowAppearance = viewModel.priceImpactSeverity.rowAppearance
        return VStack(spacing: 0) {
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.rate,
                value: model.rateLine,
                trailingAccessory: AnyView(
                    CircularLoader(
                        preset: .small,
                        duration: viewModel.confirmationRefreshDuration,
                        onComplete: {
                            viewModel.notifyCircularProgressCompleted()
                        },
                        restartToken: viewModel.circularProgressRestartToken
                    )
                )
            )
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.slippage,
                value: model.slippageLine,
                hintText: TKLocales.NativeSwap.Screen.Confirm.Field.Slippage.info,
                onTap: viewModel.canSelectSlippage
                    ? { sourceView in
                        viewModel.requestSlippageSelection(sourceView: sourceView)
                    }
                    : nil,
                trailingIcon: viewModel.canSelectSlippage ? .TKUIKit.Icons.Size16.switch : nil
            )
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.minimumReceived,
                value: model.minimumReceivedLine
            )
            if let priceImpactValue = model.priceImpactValue {
                MultichainSwapConfirmationDetailRow(
                    title: model.priceImpactTitle,
                    value: priceImpactValue,
                    hintText: TKLocales.NativeSwap.Screen.Confirm.Field.ValueDifference.info,
                    valueColor: priceImpactRowAppearance.color,
                    trailingIcon: priceImpactRowAppearance.icon,
                    trailingIconColor: priceImpactRowAppearance.color
                )
            }
            MultichainSwapConfirmationFeeRow(
                title: model.networkFeeTitle,
                value: model.networkFeeValue,
                method: model.networkFeeMethod,
                subtitle: model.networkFeeSubtitle,
                showsDivider: viewModel.showsUnlimitedApprovalToggle || hasExecutionStatus,
                onMethodTap: model.canPickFeeMethod
                    ? { viewModel.openFeeMethodPicker() }
                    : nil
            )
            if viewModel.showsUnlimitedApprovalToggle {
                Toggle(isOn: Binding(
                    get: { viewModel.isUnlimitedApprovalEnabled },
                    set: { viewModel.setUnlimitedApprovalEnabled($0) }
                )) {
                    Text(TKLocales.MultichainSwap.Screen.Confirm.Approval.avoidExtraFees)
                        .textStyle(.body1)
                        .foregroundStyle(.textPrimary)
                }
                .disabled(!viewModel.canChangeApprovalMode)
                .toggleStyle(SwitchToggleStyle(tint: palette.accent.blue))
                .padding(16)

                if hasExecutionStatus {
                    Rectangle()
                        .fill(.separatorCommon)
                        .frame(height: 1 / UIScreen.main.scale)
                        .padding(.leading, 16)
                }
            }
            if let executionStatusLine = viewModel.executionState.statusLine {
                MultichainSwapConfirmationDetailRow(
                    title: TKLocales.MultichainSwap.Screen.Confirm.Field.status,
                    value: executionStatusLine,
                    isLast: true
                )
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PriceImpactRowAppearance {
    let color: TKColor
    let icon: UIImage?
}

private extension MultichainSwapPriceImpactSeverity {
    var rowAppearance: PriceImpactRowAppearance {
        switch self {
        case .none:
            return PriceImpactRowAppearance(
                color: .textPrimary,
                icon: nil
            )
        case .warning:
            return PriceImpactRowAppearance(
                color: .accentOrange,
                icon: .TKUIKit.Icons.Size16.exclamationMarkCircle
            )
        case .danger:
            return PriceImpactRowAppearance(
                color: .accentRed,
                icon: .TKUIKit.Icons.Size16.exclamationmarkTriangle
            )
        }
    }
}

private extension MultichainSwapPriceImpactSeverity {
    var sliderAppearance: TKSlider.Appearance {
        switch self {
        case .none:
            return .standart
        case .warning:
            return .warning
        case .danger:
            return .danger
        }
    }
}
