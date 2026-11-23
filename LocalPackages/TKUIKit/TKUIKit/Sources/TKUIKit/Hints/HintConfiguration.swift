import UIKit

public enum HintAnimationStyle {
    case bouncing
}

public struct HintConfiguration {
    public var position: HintPosition
    public var maximumWidth: CGFloat
    public var animationStyle: HintAnimationStyle
    public var requiresVisibleSource: Bool

    public init(
        position: HintPosition,
        maximumWidth: CGFloat = 200,
        animationStyle: HintAnimationStyle,
        requiresVisibleSource: Bool = false
    ) {
        self.position = position
        self.maximumWidth = maximumWidth
        self.animationStyle = animationStyle
        self.requiresVisibleSource = requiresVisibleSource
    }
}
