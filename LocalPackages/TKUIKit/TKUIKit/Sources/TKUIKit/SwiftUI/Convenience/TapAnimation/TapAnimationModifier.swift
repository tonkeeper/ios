import SwiftUI
import UIKit

public enum TKTapAnimationHaptic {
    case none
    case soft
    case light
}

public extension View {
    func tkTapAnimation(
        isPressed: Bool,
        haptic: TKTapAnimationHaptic = .none
    ) -> some View {
        modifier(TapAnimationModifier(isPressed: isPressed, haptic: haptic))
    }
}

public struct TKTapAnimationButtonStyle: ButtonStyle {
    private let haptic: TKTapAnimationHaptic

    public init(haptic: TKTapAnimationHaptic = .none) {
        self.haptic = haptic
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: haptic)
    }
}

enum TapAnimation {
    static let scale: CGFloat = 0.98
    static let pressAnimation: Animation = .timingCurve(0.3, 0.75, 0.45, 1, duration: 0.12)
    static let releaseAnimation: Animation = .timingCurve(0.34, 1.7, 0.45, 1, duration: 0.42)
}

struct TapAnimationModifier: ViewModifier {
    let isPressed: Bool
    let haptic: TKTapAnimationHaptic

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var feedbackGenerator: UIImpactFeedbackGenerator

    init(isPressed: Bool, haptic: TKTapAnimationHaptic) {
        self.isPressed = isPressed
        self.haptic = haptic
        _feedbackGenerator = State(
            initialValue: UIImpactFeedbackGenerator(
                style: haptic.feedbackStyle ?? .light
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? TapAnimation.scale : 1)
            .animation(isPressed ? TapAnimation.pressAnimation : TapAnimation.releaseAnimation, value: isPressed)
            .onChange(of: isPressed) { isPressed in
                guard haptic.feedbackStyle != nil, isPressed else {
                    return
                }
                feedbackGenerator.impactOccurred()
            }
    }
}

extension TKTapAnimationHaptic {
    public func impactOccurred() {
        guard let feedbackStyle else {
            return
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }

    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle? {
        switch self {
        case .none:
            nil
        case .soft:
            .soft
        case .light:
            .light
        }
    }
}
