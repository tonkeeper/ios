import SwiftUI

private struct HintButtonPreviewPlayground: View {
    private let selectedDirection: RequestedDirection
    @Environment(\.tkPalette) private var palette
    @State private var horizontalMode = HorizontalMode.relative
    @State private var horizontalValue = 0.0
    @State private var verticalOffset = 8.0
    @State private var maximumWidth = 220.0
    @State private var messageVariant = MessageVariant.long
    init(initialDirection: RequestedDirection) {
        selectedDirection = initialDirection
    }

    var body: some View {
        interactiveCoverage
            .padding(.vertical, 20)
            .ignoresSafeArea(.all)
            .debugPreview(background: .page)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: Layout.controlSpacing) {
            VStack(alignment: .leading, spacing: Layout.controlLabelSpacing) {
                Text("Horizontal Mode")
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)

                Picker("Horizontal Mode", selection: $horizontalMode) {
                    ForEach(HorizontalMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            sliderRow(
                title: horizontalMode.sliderTitle,
                value: horizontalValueText,
                range: horizontalMode.range,
                step: horizontalMode.step,
                binding: $horizontalValue
            )

            sliderRow(
                title: "Vertical Offset",
                value: "\(Int(verticalOffset)) pt",
                range: 0 ... 48,
                step: 1,
                binding: $verticalOffset
            )

            sliderRow(
                title: "Maximum Width",
                value: "\(Int(maximumWidth)) pt",
                range: 120 ... 320,
                step: 10,
                binding: $maximumWidth
            )

            VStack(alignment: .leading, spacing: Layout.controlLabelSpacing) {
                Text("Message")
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)

                Picker("Message", selection: $messageVariant) {
                    ForEach(MessageVariant.allCases) { variant in
                        Text(variant.title).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var interactiveCoverage: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    previewButton("Top Left")
                    Spacer()
                    previewButton("Top Right")
                }

                Spacer(minLength: Layout.canvasSpacing)

                HStack {
                    Spacer()
                    previewButton("Center")
                    Spacer()
                }

                controlPanel
                    .padding(.vertical, 48)

                HStack {
                    previewButton("Bottom Left")
                    Spacer()
                    previewButton("Bottom Right")
                }
            }
            .padding(Layout.canvasPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewButton(_ title: String) -> some View {
        HintButton(configuration: activeConfiguration) { position in
            TKHintTextView(
                text: previewText(
                    anchor: title,
                    requested: selectedDirection.value,
                    resolved: position
                ),
                position: position
            )
        } label: {
            previewLabel(title)
        }
    }

    private func previewLabel(_ title: String) -> some View {
        Text(title)
            .textStyle(.body2)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Layout.labelHorizontalPadding)
            .padding(.vertical, Layout.labelVerticalPadding)
            .background(
                palette.background.contentTint
                    .clipped()
            )
    }

    private func sliderRow(
        title: String,
        value: String,
        range: ClosedRange<Double>,
        step: Double,
        binding: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.controlLabelSpacing) {
            HStack {
                Text(title)
                    .textStyle(.label2)
                    .foregroundStyle(.textSecondary)

                Spacer(minLength: Layout.minimumSpacer)

                Text(value)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
            }

            Slider(
                value: binding,
                in: range,
                step: step
            )
            .tint(.accentBlue)
        }
    }

    private func configuration(for direction: RequestedDirection) -> HintConfiguration {
        HintConfiguration(
            position: HintPosition(
                tailParameters: TKHintTextView.tailParameters,
                horizontal: horizontalPosition,
                vertical: .init(absolute: CGFloat(verticalOffset)),
                direction: direction.value
            ),
            maximumWidth: CGFloat(maximumWidth),
            animationStyle: .bouncing
        )
    }

    private var activeConfiguration: HintConfiguration {
        configuration(for: selectedDirection)
    }

    private var horizontalPosition: HintPosition.HorizontalPosition {
        switch horizontalMode {
        case .relative:
            .relative(CGFloat(horizontalValue))
        case .relativeToGlobal:
            .relativeToGlobal(CGFloat(horizontalValue))
        case .absolute:
            .absolute(CGFloat(horizontalValue))
        }
    }

    private var horizontalValueText: String {
        switch horizontalMode {
        case .relative, .relativeToGlobal:
            horizontalValue.formatted(.number.precision(.fractionLength(2)))
        case .absolute:
            "\(Int(horizontalValue)) pt"
        }
    }

    private func previewText(
        anchor: String,
        requested: HintPosition.Direction,
        resolved: HintPosition.Direction?
    ) -> String {
        let resolvedDirection = resolved ?? requested
        return [
            anchor,
            "Requested: \(RequestedDirection(direction: requested).title)",
            "Resolved: \(RequestedDirection(direction: resolvedDirection).title)",
            messageVariant.text,
        ]
        .joined(separator: "\n")
    }
}

private extension HintButtonPreviewPlayground {
    enum Layout {
        static let controlSpacing: CGFloat = 16
        static let controlLabelSpacing: CGFloat = 8
        static let minimumSpacer: CGFloat = 12
        static let canvasPadding: CGFloat = 24
        static let canvasSpacing: CGFloat = 16
        static let labelHorizontalPadding: CGFloat = 14
        static let labelVerticalPadding: CGFloat = 10
    }

    enum RequestedDirection: String, CaseIterable, Identifiable {
        case topLeft
        case topCenter
        case topRight
        case bottomLeft
        case bottomCenter
        case bottomRight

        init(direction: HintPosition.Direction) {
            switch direction {
            case .topLeft:
                self = .topLeft
            case .topCenter:
                self = .topCenter
            case .topRight:
                self = .topRight
            case .bottomLeft:
                self = .bottomLeft
            case .bottomCenter:
                self = .bottomCenter
            case .bottomRight:
                self = .bottomRight
            }
        }

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .topLeft:
                "Top Left"
            case .topCenter:
                "Top Center"
            case .topRight:
                "Top Right"
            case .bottomLeft:
                "Bottom Left"
            case .bottomCenter:
                "Bottom Center"
            case .bottomRight:
                "Bottom Right"
            }
        }

        var value: HintPosition.Direction {
            switch self {
            case .topLeft:
                .topLeft
            case .topCenter:
                .topCenter
            case .topRight:
                .topRight
            case .bottomLeft:
                .bottomLeft
            case .bottomCenter:
                .bottomCenter
            case .bottomRight:
                .bottomRight
            }
        }
    }

    enum HorizontalMode: String, CaseIterable, Identifiable {
        case relative
        case relativeToGlobal
        case absolute

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .relative:
                "Relative"
            case .relativeToGlobal:
                "Global"
            case .absolute:
                "Absolute"
            }
        }

        var sliderTitle: String {
            switch self {
            case .relative:
                "Horizontal Offset"
            case .relativeToGlobal:
                "Global Horizontal Offset"
            case .absolute:
                "Horizontal Offset"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .relative, .relativeToGlobal:
                -1 ... 1
            case .absolute:
                -120 ... 120
            }
        }

        var step: Double {
            switch self {
            case .relative, .relativeToGlobal:
                0.05
            case .absolute:
                4
            }
        }
    }

    enum MessageVariant: String, CaseIterable, Identifiable {
        case short
        case medium
        case long

        var id: Self {
            self
        }

        var title: String {
            rawValue.capitalized
        }

        var text: String {
            switch self {
            case .short:
                "Short body."
            case .medium:
                "Two lines of helper copy to confirm the bubble size remains stable."
            case .long:
                "A longer helper message that stresses wrapping, preferredContentSize and window-edge fallback behaviour for the universal tooltip controller."
            }
        }
    }
}

#Preview("Top Left") {
    HintButtonPreviewPlayground(initialDirection: .topLeft)
        .tkThemed()
}

#Preview("Top Center") {
    HintButtonPreviewPlayground(initialDirection: .topCenter)
        .tkThemed()
}

#Preview("Top Right") {
    HintButtonPreviewPlayground(initialDirection: .topRight)
        .tkThemed()
}

#Preview("Bottom Left") {
    HintButtonPreviewPlayground(initialDirection: .bottomLeft)
        .tkThemed()
}

#Preview("Bottom Center") {
    HintButtonPreviewPlayground(initialDirection: .bottomCenter)
        .tkThemed()
}

#Preview("Bottom Right") {
    HintButtonPreviewPlayground(initialDirection: .bottomRight)
        .tkThemed()
}
