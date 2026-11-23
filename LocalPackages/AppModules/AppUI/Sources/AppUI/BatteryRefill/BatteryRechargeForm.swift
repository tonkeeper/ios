import SwiftUI
import TKLocalize
import TKUIKit

public struct BatteryRechargeFormState {
    public var title: String
    public var symbol: String
    public var image: AssetAvatarViewImageSource
    public var packs: [BatteryRefillViewState.Pack]
    public var showsAmount: Bool
    public var isEnabled: Bool
    public var isBusy: Bool
    public var isLoadingPaymentMethods: Bool
    public var message: String?
    public var continueIdentifier: String
    public var pinsContinueButton: Bool

    public init(title: String, symbol: String, image: AssetAvatarViewImageSource, packs: [BatteryRefillViewState.Pack] = [], showsAmount: Bool = false, isEnabled: Bool = false, isBusy: Bool = false, isLoadingPaymentMethods: Bool = false, message: String? = nil, continueIdentifier: String = "battery_recharge_continue", pinsContinueButton: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.image = image
        self.packs = packs
        self.showsAmount = showsAmount
        self.isEnabled = isEnabled
        self.isBusy = isBusy
        self.isLoadingPaymentMethods = isLoadingPaymentMethods
        self.message = message
        self.continueIdentifier = continueIdentifier
        self.pinsContinueButton = pinsContinueButton
    }
}

public struct BatteryRechargeForm<Amount: View, Promo: View, Recipient: View>: View {
    private let state: BatteryRechargeFormState
    private let onSelectPack: (String) -> Void
    private let onSelectAsset: () -> Void
    private let onContinue: () -> Void
    private let onClose: () -> Void
    private let endEditing: () -> Void
    private let onRetry: (() -> Void)?
    private let amount: Amount
    private let promo: Promo
    private let recipient: Recipient

    public init(state: BatteryRechargeFormState, onSelectPack: @escaping (String) -> Void, onSelectAsset: @escaping () -> Void, onContinue: @escaping () -> Void, onClose: @escaping () -> Void, endEditing: @escaping () -> Void, onRetry: (() -> Void)? = nil, @ViewBuilder amount: () -> Amount, @ViewBuilder promo: () -> Promo, @ViewBuilder recipient: () -> Recipient) {
        self.state = state
        self.onSelectPack = onSelectPack
        self.onSelectAsset = onSelectAsset
        self.onContinue = onContinue
        self.onClose = onClose
        self.endEditing = endEditing
        self.onRetry = onRetry
        self.amount = amount()
        self.promo = promo()
        self.recipient = recipient()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    recipient
                    BatteryPacksView(packs: state.packs, onSelect: { id in
                        endEditing()
                        onSelectPack(id)
                    })
                    .padding(.top, state.pinsContinueButton ? 8 : 0)
                    .disabled(state.isBusy)
                    if state.showsAmount {
                        amount.padding(.horizontal, 16).disabled(state.isBusy)
                    }
                    promo.padding(.horizontal, 16).disabled(state.isBusy)
                    if let message = state.message {
                        Text(message)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("battery_purchase_message")
                        if let onRetry {
                            Button(TKLocales.Actions.retry, action: onRetry).foregroundStyle(.accentBlue)
                        }
                    }
                    if !state.pinsContinueButton {
                        continueButton.padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
            .tkImmediateButtonPresses()
            .tkDismissesKeyboardInteractively()
            .tkAdditionalKeyboardPadding(32)
            .onTapGesture(perform: endEditing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if state.pinsContinueButton {
                continueButton
                    .padding(16)
                    .background(.backgroundPage)
            }
        }
        .background(.backgroundPage)
    }

    private var continueButton: some View {
        ButtonView(config: .init(title: TKLocales.Actions.continueAction, size: .large, layoutMode: .fill, appearance: .primary, showsLoader: state.isBusy, action: {
            endEditing()
            onContinue()
        }))
        .disabled(!state.isEnabled || state.isBusy)
        .accessibilityIdentifier(state.continueIdentifier)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(state.title).textStyle(.h3).foregroundStyle(.textPrimary).lineLimit(1)
            Spacer(minLength: 0)
            if state.isLoadingPaymentMethods {
                CircularLoader(mode: .indeterminate, preset: .small)
                    .frame(width: 24, height: 24)
                    .accessibilityIdentifier("battery_recharge_methods_loading")
            }
            MultichainSwapTokenPickerCapsule(imageSource: state.image, symbol: state.symbol, action: {
                endEditing()
                onSelectAsset()
            })
            .disabled(state.isBusy || state.isLoadingPaymentMethods)
            .accessibilityIdentifier("battery_recharge_token_picker")
            Button(action: onClose) {
                Image(uiImage: state.pinsContinueButton ? .TKUIKit.Icons.Size28.xmarkOutline : .TKUIKit.Icons.Size16.close)
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: state.pinsContinueButton ? 28 : 16, height: state.pinsContinueButton ? 28 : 16)
                    .foregroundStyle(.buttonSecondaryForeground)
                    .padding(8)
                    .background(.buttonSecondaryBackground)
                    .clipShape(Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
            .accessibilityLabel(TKLocales.Actions.cancel)
            .accessibilityIdentifier("battery_recharge_close")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .background(.backgroundPage)
        .contentShape(Rectangle())
        .onTapGesture(perform: endEditing)
    }
}
