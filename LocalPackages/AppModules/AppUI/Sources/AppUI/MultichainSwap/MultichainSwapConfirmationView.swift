import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

/// The swap settings sheet's body: the swap screen's quote, the plan's fee, and a Swap of its own.
public struct MultichainSwapConfirmationView: View {
    public let state: MultichainSwapConfirmationViewState
    public let actions: MultichainSwapConfirmationViewActions

    public init(
        state: MultichainSwapConfirmationViewState,
        actions: MultichainSwapConfirmationViewActions
    ) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            detailsCard
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            actionArea
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 3, trailing: 16))
        }
        .background(.backgroundPage)
    }
}

private extension MultichainSwapConfirmationView {
    @ViewBuilder
    var actionArea: some View {
        switch state.action {
        case let .swap(isEnabled, isLoading):
            ButtonView(
                config: .init(
                    title: TKLocales.WalletButtons.swap,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    showsLoader: isLoading,
                    action: actions.confirm
                )
            )
            .disabled(!isEnabled || isLoading)
            .accessibilityIdentifier("swap_confirm")
        case .feeUnpaid:
            ButtonView(
                config: .init(
                    title: TKLocales.WalletButtons.swap,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .secondary,
                    action: actions.confirm
                )
            )
            .accessibilityIdentifier("swap_confirm")
        case .topUpBattery:
            ButtonView(
                config: .init(
                    title: TKLocales.MultichainSwap.Screen.Confirm.topUpBattery,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: actions.topUpBattery
                )
            )
            .accessibilityIdentifier("swap_top_up_battery")
        case let .quoteFailed(message):
            MultichainSwapConfirmationQuoteFailureView(
                message: message,
                onRetry: actions.retryQuote
            )
            .frame(height: Layout.failureHeight)
        case let .sendFailed(message):
            TKResultSwiftUIView(state: .failure, title: message)
                .frame(maxWidth: .infinity)
                .frame(height: Layout.failureHeight)
        }
    }

    var detailsCard: some View {
        VStack(spacing: 0) {
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.rate,
                value: state.rateLine,
                trailingAccessory: quoteProgress
            )
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.minimumReceived,
                value: state.minimumReceivedLine,
                subtitle: state.minimumReceivedFiatLine
            )
            MultichainSwapConfirmationDetailRow(
                title: TKLocales.MultichainSwap.Screen.Confirm.Field.slippage,
                value: state.slippageLine,
                hintText: TKLocales.NativeSwap.Screen.Confirm.Field.Slippage.info,
                onTap: state.canSelectSlippage ? actions.selectSlippage : nil,
                trailingIcon: state.canSelectSlippage ? .TKUIKit.Icons.Size16.switch : nil
            )
            MultichainSwapConfirmationFeeRow(
                title: state.networkFee.title,
                value: state.networkFee.value,
                method: state.networkFee.method,
                subtitle: state.networkFee.subtitle,
                isShortage: state.networkFee.isShortage,
                showsDivider: state.temporaryReserve != nil,
                onMethodTap: state.networkFee.canPickMethod ? actions.pickFeeMethod : nil,
                // A shortage with nothing to pick from opens its top-up from the row as it is.
                onTap: state.networkFee.isShortage && !state.networkFee.canPickMethod ? actions.pickFeeMethod : nil
            )
            if let temporaryReserve = state.temporaryReserve {
                MultichainSwapConfirmationDetailRow(
                    title: TKLocales.MultichainSwap.Screen.Confirm.Field.temporaryReserve,
                    value: temporaryReserve.value,
                    hintText: temporaryReserve.hint,
                    showsDivider: false
                )
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The swap screen's countdown, from where it stands: opening the sheet neither restarts it nor
    /// asks for a quote.
    var quoteProgress: AnyView? {
        switch state.quoteProgress {
        case .loading:
            return AnyView(CircularLoader(mode: .indeterminate, preset: .small))
        case let .countdown(startDate, duration):
            return AnyView(
                CircularLoader(
                    preset: .small,
                    duration: duration,
                    startDate: startDate
                )
            )
        case .none:
            return nil
        }
    }

    enum Layout {
        static let failureHeight: CGFloat = 88
    }
}
