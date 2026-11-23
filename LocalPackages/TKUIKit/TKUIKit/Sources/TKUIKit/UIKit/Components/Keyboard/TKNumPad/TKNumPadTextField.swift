import SwiftUI
import UIKit

public struct TKNumPadTextField: View {
    @Binding private var text: String
    @State private var width: CGFloat?
    @State private var proposedText: String?
    private let placeholder: String
    private let font: UIFont
    private let color: TKColor
    private let alignment: TextAlignment
    private let allowsSign: Bool
    private let presets: [TKNumPadPreset]
    private let button: TKNumPadButton?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        font: UIFont,
        color: TKColor = .textPrimary,
        alignment: TextAlignment = .leading,
        allowsSign: Bool = false,
        presets: [TKNumPadPreset] = [],
        button: TKNumPadButton? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.font = font
        self.color = color
        self.alignment = alignment
        self.allowsSign = allowsSign
        self.presets = presets
        self.button = button
    }

    public static var layoutAnimation: Animation? {
        TKNumPadView.isEnabled ? TKAnimatedAmountText.animation : nil
    }

    public static func displayText(_ text: String) -> String {
        let localized = TKAmountDigits.localized(text)
        return TKNumPadView.isEnabled ? TKAmountDigits.grouped(localized) : localized
    }

    public var body: some View {
        Group {
            if TKNumPadView.isEnabled {
                numPadField
            } else {
                TextField(placeholder, text: editedText)
                    .font(Font(font))
                    .foregroundStyle(color)
                    .multilineTextAlignment(alignment)
                    .keyboardType(.decimalPad)
            }
        }
        .onChange(of: proposedText) { value in
            if value != nil { proposedText = nil }
        }
    }

    private var editedText: Binding<String> {
        Binding(
            get: { proposedText ?? Self.displayText(text) },
            set: {
                proposedText = $0
                if let amount = TKAmountDigits.normalized($0, allowsSign: allowsSign) {
                    text = amount
                }
            }
        )
    }

    private var numPadField: some View {
        let shownText = Self.displayText(text)
        let fits = TKAmountDigits.fits(shownText, font: font, width: width ?? .infinity)
        return TextField(placeholder, text: editedText)
            .font(Font(font))
            .foregroundStyle(fits && !shownText.isEmpty ? TKColor.clear : color)
            .multilineTextAlignment(alignment)
            .overlay(alignment: Alignment(horizontal: alignment.horizontal, vertical: .center)) {
                TKAnimatedAmountText(text: shownText, font: font, color: color)
                    .opacity(fits ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { width = $0 }
            })
            .tkNumPadKeyboard(presets: presets, button: button)
    }
}

private extension TextAlignment {
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
