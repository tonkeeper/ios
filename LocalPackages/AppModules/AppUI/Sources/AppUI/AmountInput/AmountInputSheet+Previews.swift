import SwiftUI
import TKUIKit

private struct AmountInputSheetPreview: View {
    @State var state: AmountInputSheetState
    @FocusState private var focused: Bool

    var body: some View {
        AmountInputSheet(state: state, focus: $focused, onTextChange: { state.text = $0 }, onToggle: {}, onMax: {})
    }
}

#Preview("Balance loading") {
    AmountInputSheetPreview(state: AmountInputSheetState(
        text: "",
        placeholder: "",
        symbol: nil,
        converted: .init(text: "$0", showsSwitchIcon: true, isSwitchEnabled: false, isTextLoading: true),
        balance: .init(text: "", isLoading: true, showsMax: true, isMaxEnabled: false, actionTitle: "Add Funds")
    ))
    .padding()
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Long amounts", traits: .fixedLayout(width: 320, height: 720)) {
    VStack(spacing: 16) {
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "327837428347238478237",
            symbol: .text("WETH"),
            converted: .init(text: "$2.65", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: nil
        ))
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "327837428347238478237.12",
            prefix: "$",
            symbol: nil,
            converted: .init(text: "0.0011 WETH", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: nil
        ))
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "0.123456789012345678",
            symbol: .icon(.TKUIKit.Icons.Size28.ton),
            converted: .init(text: "$0.30", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: nil
        ))
    }
    .padding()
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "12.5",
            symbol: .text("TON"),
            converted: .init(text: "$ 41.20", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: .init(text: "Available: 3 906 TON", showsMax: true)
        ))
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "713",
            prefix: "$",
            symbol: nil,
            converted: .init(text: "713.14 USDC", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: .init(text: "Insufficient balance", isError: true, showsMax: true, isMaxSelected: true)
        ))
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "0.25",
            isTextLoading: true,
            symbol: .text("ETH"),
            converted: .init(text: "$500", showsSwitchIcon: true, isSwitchEnabled: true),
            balance: .init(text: "Available: 0.3 ETH", showsMax: true)
        ))
        AmountInputSheetPreview(state: AmountInputSheetState(
            text: "",
            symbol: .text("USDT"),
            converted: .init(text: "", showsSwitchIcon: false, isSwitchEnabled: false, isLoading: true),
            balance: nil
        ))
    }
    .padding()
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
