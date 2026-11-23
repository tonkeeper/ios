import SwiftUI
import TKLocalize
import TKUIKit

public struct BatteryAssetRechargeViewState {
    public var title: String
    public var network: String
    public var image: AssetAvatarViewImageSource
    public var input: AmountInputSheetState
    public var charges: String
    public var fiat: String
    public var fee: String?
    public var message: String?
    public var isConfirmation: Bool
    public var canRetry: Bool
    public var isBusy: Bool
    public var isEnabled: Bool
    public var isTerminal: Bool
    public var resetToken: Int

    public init(title: String, network: String, image: AssetAvatarViewImageSource, input: AmountInputSheetState, charges: String = "", fiat: String = "", fee: String? = nil, message: String? = nil, isConfirmation: Bool = false, canRetry: Bool = false, isBusy: Bool = false, isEnabled: Bool = false, isTerminal: Bool = false, resetToken: Int = 0) {
        self.title = title
        self.network = network
        self.image = image
        self.input = input
        self.charges = charges
        self.fiat = fiat
        self.fee = fee
        self.message = message
        self.isConfirmation = isConfirmation
        self.canRetry = canRetry
        self.isBusy = isBusy
        self.isEnabled = isEnabled
        self.isTerminal = isTerminal
        self.resetToken = resetToken
    }
}

public struct BatteryAssetRechargeView: View {
    public let state: BatteryAssetRechargeViewState
    public let onAmount: (String) -> Void
    public let onContinue: () -> Void
    public let onClose: () -> Void
    public let onRetry: () -> Void
    public let onEdit: () -> Void
    @FocusState private var isFocused: Bool

    public init(state: BatteryAssetRechargeViewState, onAmount: @escaping (String) -> Void, onContinue: @escaping () -> Void, onClose: @escaping () -> Void, onRetry: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.state = state
        self.onAmount = onAmount
        self.onContinue = onContinue
        self.onClose = onClose
        self.onRetry = onRetry
        self.onEdit = onEdit
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AssetAvatarView(imageSource: state.image)
                Text(state.title).textStyle(.h2).foregroundStyle(.textPrimary)
                Text(state.network).textStyle(.body2).foregroundStyle(.textSecondary)
                AmountInputSheet(state: state.input, focus: $isFocused, onTextChange: onAmount, onToggle: {}, onMax: {})
                    .disabled(state.isConfirmation || state.isBusy || state.isTerminal)
                if state.isConfirmation, !state.isBusy, !state.isTerminal {
                    Button(TKLocales.Actions.edit, action: onEdit).foregroundStyle(.accentBlue)
                }
                Text(state.charges).textStyle(.h2).foregroundStyle(.textPrimary)
                    .accessibilityIdentifier("battery_purchase_charges")
                if !state.fiat.isEmpty {
                    Text(state.fiat).textStyle(.body2).foregroundStyle(.textSecondary)
                }
                if let fee = state.fee {
                    HStack {
                        Text(TKLocales.MultichainSwap.Screen.Confirm.Field.networkFee)
                        Spacer()
                        Text(fee)
                    }
                    .textStyle(.body2).foregroundStyle(.textSecondary)
                }
            }
            .padding(16)
        }
        .tkDismissesKeyboardInteractively()
        .safeAreaInset(edge: .top) {
            DefaultModalCardHeader(config: .init(rightIcon: .close(accessibilityIdentifier: "battery_purchase_close") { _ in onClose() }, height: .atLeast(56), background: .scrim))
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                if let message = state.message {
                    Text(message).textStyle(.body2).foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("battery_purchase_message")
                    if !state.isBusy, !state.isTerminal, state.canRetry || !state.isConfirmation {
                        Button(TKLocales.Actions.retry, action: onRetry).foregroundStyle(.accentBlue)
                            .accessibilityIdentifier("battery_purchase_retry")
                    }
                }
                if state.isBusy {
                    ProgressView()
                } else if state.isConfirmation, !state.isTerminal {
                    TKSwipeToConfirmView(
                        title: TKLocales.Actions.Confirm.title,
                        subtitle: TKLocales.Actions.Confirm.subtitle,
                        isEnabled: state.isEnabled,
                        resetToken: state.resetToken,
                        handleAccessibilityIdentifier: "battery_purchase_confirm",
                        onConfirm: onContinue
                    )
                } else if !state.isTerminal {
                    ButtonView(config: .init(title: TKLocales.Actions.continueAction, size: .large, layoutMode: .fill, appearance: .primary, action: {
                        isFocused = false
                        onContinue()
                    }))
                    .disabled(!state.isEnabled)
                    .accessibilityIdentifier("battery_purchase_continue")
                }
            }
            .padding(16)
            .background(.backgroundPage)
        }
        .background(.backgroundPage)
    }
}
