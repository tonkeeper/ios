import AppUI
import SwiftUI
import TKUIKit
import UIKit

struct MoonPayRampScreen: View {
    @ObservedObject var viewModel: MoonPayRampViewModel
    @FocusState private var focused: Bool

    var body: some View {
        MoonPayRampView(
            state: viewModel.screenState,
            focus: $focused,
            focusesOnAppear: true,
            onTextChange: viewModel.amountViewModel.setText,
            onQuickOption: viewModel.amountViewModel.selectQuickOption,
            onConvertedTap: viewModel.amountViewModel.tapConverted,
            onCurrencyTap: viewModel.tapCurrency,
            onToggleRateDirection: viewModel.toggleRateDirection,
            onRateTimerCompleted: viewModel.completeRateTimer,
            onPriceDetails: viewModel.tapPriceDetails,
            onPaymentMethodTap: viewModel.tapPaymentMethod,
            onAction: viewModel.tapAction,
            onCryptoDeposit: viewModel.tapCryptoDeposit,
            onClose: viewModel.close,
            inlineAction: viewModel.inlineAction.map(InlineActionView.init)
        )
        // The controller insets the screen over the keyboard itself, see `MoonPayRampViewController`.
        .ignoresSafeArea(.keyboard)
        .onChange(of: viewModel.amountFocusRequest) { _ in
            // The status sheet resigned the field through UIKit, which may leave the focus state
            // true: setting it again would change nothing.
            focused = false
            let request = viewModel.amountFocusRequest
            DispatchQueue.main.async {
                guard viewModel.amountFocusRequest == request else { return }
                focused = true
            }
        }
    }
}

private struct InlineActionView: View {
    let action: RampInlineAction

    var body: some View {
        ZStack {
            if let controller = action.controller {
                // Stays in the hierarchy while hidden: the frame loads only inside a window.
                InlineActionFrame(controller: controller)
                    .id(ObjectIdentifier(controller))
                    .allowsHitTesting(action.isReady && action.isEnabled)
                    .opacity(action.isReady ? (action.isEnabled ? 1 : 0.48) : 0)
            }
            if !action.isReady {
                ShimmerSwiftUIView(config: .init(
                    color: .backgroundContentTint,
                    cornerRadius: .value(RampInlineAction.cornerRadius)
                ))
            }
        }
        .frame(height: RampInlineAction.height)
        .clipShape(RoundedRectangle(cornerRadius: RampInlineAction.cornerRadius, style: .continuous))
    }
}

private struct InlineActionFrame: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
