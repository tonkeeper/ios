import AppUI
import SwiftUI
import TKUIKit
import UIKit

struct AmountInputSwiftUIView: View {
    @ObservedObject var viewModel: AmountInputSwiftUIViewModel
    var textFieldAccessibilityIdentifier: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        AmountInputSheet(
            state: viewModel.sheetState(textFieldAccessibilityIdentifier: textFieldAccessibilityIdentifier),
            focus: $isFocused,
            onTextChange: viewModel.setText,
            onToggle: viewModel.toggle,
            onMax: viewModel.tapMax,
            onConvertedTap: viewModel.tapConverted,
            onQuickOption: viewModel.selectQuickOption
        )
        // A request can land before the first render, when onChange does not see it yet.
        .onAppear { focusIfRequested() }
        .onChange(of: viewModel.focusRequest) { _ in focusIfRequested() }
    }

    private func focusIfRequested() {
        guard viewModel.focusRequest > 0 else { return }
        DispatchQueue.main.async { isFocused = true }
    }
}

extension AmountInputSwiftUIViewModel {
    func sheetState(textFieldAccessibilityIdentifier: String? = nil) -> AmountInputSheetState {
        let converted = converted
        let balance = balance
        return AmountInputSheetState(
            text: text,
            symbol: inputSymbol.cardSymbol,
            converted: converted.isHidden ? nil : .init(
                text: converted.text,
                symbol: converted.symbol.cardSymbol,
                showsSwitchIcon: converted.showsSwitchIcon,
                isSwitchEnabled: converted.isSwitchEnabled,
                isLoading: converted.showsShimmer,
                showsChevron: converted.showsChevron,
                leadingImage: converted.leadingImage,
                leadingImageURL: converted.leadingImageURL
            ),
            quickOptions: quickOptionRows.map { option in
                .init(
                    id: option.id,
                    title: option.title,
                    isSelected: option.id == selectedQuickOptionID
                )
            },
            balance: showsBalance ? .init(
                text: balance.text,
                isError: balance.isError,
                showsMax: balance.showsMaxButton,
                isMaxSelected: balance.isMaxSelected,
                maxHint: balance.maxHint,
                errorHint: balance.errorHint
            ) : nil,
            textFieldAccessibilityIdentifier: textFieldAccessibilityIdentifier
        )
    }
}

private extension AmountInputSymbol {
    var cardSymbol: AmountInputSheetState.Symbol {
        switch self {
        case let .icon(image): .icon(image)
        case let .text(text): .text(text)
        }
    }
}
