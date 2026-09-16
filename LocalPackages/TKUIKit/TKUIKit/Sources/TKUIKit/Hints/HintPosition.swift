import UIKit

public struct HintPosition: Sendable {
    public var tailParameters: HintTailParameters?
    public var horizontal: HorizontalPosition
    public var vertical: VerticalPosition
    public var direction: Direction

    public init(
        tailParameters: HintTailParameters?,
        horizontal: HorizontalPosition,
        vertical: VerticalPosition,
        direction: Direction
    ) {
        self.tailParameters = tailParameters
        self.horizontal = horizontal
        self.vertical = vertical
        self.direction = direction
    }

    var mirroredHorizontally: Self {
        Self(
            tailParameters: tailParameters,
            horizontal: horizontal.mirrored,
            vertical: vertical,
            direction: direction.mirroredHorizontally
        )
    }

    var mirroredVertically: Self {
        Self(
            tailParameters: tailParameters,
            horizontal: horizontal,
            vertical: vertical,
            direction: direction.mirroredVertically
        )
    }

    var centered: Self {
        Self(
            tailParameters: tailParameters,
            horizontal: horizontal,
            vertical: vertical,
            direction: direction.centeredHorizontally
        )
    }

    var cornerOptions: [Self] {
        [
            Self(
                tailParameters: tailParameters,
                horizontal: horizontal.relativeOption(0),
                vertical: vertical,
                direction: direction
            ),
            Self(
                tailParameters: tailParameters,
                horizontal: horizontal.relativeOption(1),
                vertical: vertical,
                direction: direction
            ),
        ]
    }

    public static var `default`: Self {
        Self(
            tailParameters: nil,
            horizontal: .default,
            vertical: .default,
            direction: .topRight
        )
    }
}

public extension HintPosition {
    enum HorizontalPosition: Sendable {
        /// offset from midX of the source view where 1 is maxX and -1 is minX
        case relative(CGFloat)
        /// offset from midX of the global coordinate space where 1 is maxX and -1 is minX
        case relativeToGlobal(CGFloat)
        /// offset from midX of the source view in points
        case absolute(CGFloat)

        var mirrored: Self {
            switch self {
            case let .relative(value):
                .relative(-value)
            case let .relativeToGlobal(value):
                .relativeToGlobal(-value)
            case let .absolute(value):
                .absolute(-value)
            }
        }

        public func absoluteValue(
            in frame: CGRect,
            globalFrame: CGRect
        ) -> CGFloat {
            switch self {
            case let .relative(value):
                frame.midX + frame.width * value * 0.5
            case let .relativeToGlobal(value):
                globalFrame.midX + globalFrame.width * value * 0.5
            case let .absolute(value):
                frame.midX + value
            }
        }

        func relativeOption(_ value: CGFloat) -> Self {
            switch self {
            case .relativeToGlobal:
                .relativeToGlobal(value)
            case .relative, .absolute:
                .relative(value)
            }
        }

        public static var `default`: Self {
            .relative(0)
        }
    }
}

public extension HintPosition {
    struct VerticalPosition: Sendable {
        public var absolute: CGFloat

        public init(absolute: CGFloat) {
            self.absolute = absolute
        }

        public static var `default`: Self {
            Self(absolute: 0)
        }
    }
}

public extension HintPosition {
    enum Direction: Sendable {
        case topLeft
        case topCenter
        case topRight
        case bottomLeft
        case bottomCenter
        case bottomRight

        var mirroredHorizontally: Self {
            switch self {
            case .topLeft:
                .topRight
            case .topCenter:
                .topCenter
            case .topRight:
                .topLeft
            case .bottomLeft:
                .bottomRight
            case .bottomCenter:
                .bottomCenter
            case .bottomRight:
                .bottomLeft
            }
        }

        var centeredHorizontally: Self {
            switch self {
            case .topLeft, .topCenter, .topRight:
                .topCenter
            case .bottomLeft, .bottomCenter, .bottomRight:
                .bottomCenter
            }
        }

        var mirroredVertically: Self {
            switch self {
            case .topLeft:
                .bottomLeft
            case .topCenter:
                .bottomCenter
            case .topRight:
                .bottomRight
            case .bottomLeft:
                .topLeft
            case .bottomCenter:
                .topCenter
            case .bottomRight:
                .topRight
            }
        }
    }
}
