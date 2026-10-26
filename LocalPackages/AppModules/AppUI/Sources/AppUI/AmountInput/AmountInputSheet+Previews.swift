import SwiftUI
import TKUIKit

private struct AmountInputSheetPreview: View {
    let state: AmountInputSheetState
    @FocusState private var focused: Bool

    var body: some View {
        AmountInputSheet(state: state, focus: $focused, onTextChange: { _ in }, onToggle: {}, onMax: {})
    }
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
