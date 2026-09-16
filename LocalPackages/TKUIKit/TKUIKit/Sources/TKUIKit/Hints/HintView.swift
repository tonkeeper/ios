import SwiftUI

public struct HintAppearance {
    let backgroundColor: TKColor
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    public init(
        backgroundColor: TKColor,
        cornerRadius: CGFloat,
        shadowColor: Color,
        shadowRadius: CGFloat,
        shadowYOffset: CGFloat
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowYOffset = shadowYOffset
    }
}

protocol HintView: View {
    static var appearance: HintAppearance { get }
}

extension HintView {
    static var appearance: HintAppearance {
        HintAppearance(
            backgroundColor: .backgroundContentTint,
            cornerRadius: 12,
            shadowColor: Color.black.opacity(0.04),
            shadowRadius: 8,
            shadowYOffset: 4
        )
    }
}

private struct TailModifier: ViewModifier {
    let appearance: HintAppearance
    let tailParameters: HintTailParameters?
    let direction: HintPosition.Direction?

    func body(content: Content) -> some View {
        padded(
            content: content
                .background(background)
                .shadow(
                    color: appearance.shadowColor,
                    radius: appearance.shadowRadius,
                    x: 0,
                    y: appearance.shadowYOffset
                )
        )
    }

    @ViewBuilder
    private func padded(content: some View) -> some View {
        if let direction, let tailParameters {
            switch direction {
            case .topLeft, .topCenter, .topRight:
                content
                    .padding(.bottom, tailParameters.size.height)
            case .bottomLeft, .bottomCenter, .bottomRight:
                content
                    .padding(.top, tailParameters.size.height)
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var background: some View {
        if let tailParameters, let direction {
            switch direction {
            case .topLeft:
                bubble(side: .bottomRight, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            case .topCenter:
                bubble(side: .bottomCenter, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            case .topRight:
                bubble(side: .bottomLeft, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            case .bottomLeft:
                bubble(side: .topRight, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            case .bottomCenter:
                bubble(side: .topCenter, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            case .bottomRight:
                bubble(side: .topLeft, parameters: tailParameters)
                    .fill(appearance.backgroundColor)
            }
        } else {
            RoundedRectangle(
                cornerRadius: appearance.cornerRadius,
                style: .continuous
            )
            .fill(appearance.backgroundColor)
        }
    }

    private func bubble(side: HintPosition.Direction, parameters: HintTailParameters) -> some Shape {
        HintMessageBubble(
            side: side,
            tailCornerRadius: parameters.tailCornerRadius,
            bubbleCornerRadius: appearance.cornerRadius,
            tailSize: parameters.size,
            tailOffset: parameters.horizontalOffset
        )
    }
}

extension View {
    func withTail(
        appearance: HintAppearance,
        parameters: HintTailParameters?,
        direction: HintPosition.Direction?
    ) -> some View {
        modifier(
            TailModifier(
                appearance: appearance,
                tailParameters: parameters,
                direction: direction
            )
        )
    }
}
