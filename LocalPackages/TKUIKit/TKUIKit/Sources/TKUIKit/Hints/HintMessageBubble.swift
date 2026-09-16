import SwiftUI

struct HintMessageBubble: Shape {
    private let side: HintPosition.Direction
    private let tailCornerRadius: CGFloat
    private let bubbleCornerRadius: CGFloat
    private let tailSize: CGSize
    private let tailOffset: CGFloat

    init(
        side: HintPosition.Direction,
        tailCornerRadius: CGFloat,
        bubbleCornerRadius: CGFloat,
        tailSize: CGSize,
        tailOffset: CGFloat
    ) {
        self.side = side
        self.tailCornerRadius = tailCornerRadius
        self.bubbleCornerRadius = bubbleCornerRadius
        self.tailSize = tailSize
        self.tailOffset = tailOffset
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )

        path.addRoundedRect(
            in: bubbleRect,
            cornerSize: CGSize(
                width: bubbleCornerRadius,
                height: bubbleCornerRadius
            )
        )
        let tailOffset = tailOffset

        let tailRight: CGPoint
        let tailTop: CGPoint
        let tailLeft: CGPoint

        switch side {
        case .bottomLeft:
            tailRight = CGPoint(
                x: bubbleRect.minX + tailOffset - tailSize.width / 2,
                y: bubbleRect.maxY
            )
            tailTop = CGPoint(
                x: bubbleRect.minX + tailOffset,
                y: bubbleRect.maxY + tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.minX + tailOffset + tailSize.width / 2,
                y: bubbleRect.maxY
            )
        case .bottomRight:
            tailRight = CGPoint(
                x: bubbleRect.maxX - tailOffset - tailSize.width / 2,
                y: bubbleRect.maxY
            )
            tailTop = CGPoint(
                x: bubbleRect.maxX - tailOffset,
                y: bubbleRect.maxY + tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.maxX - tailOffset + tailSize.width / 2,
                y: bubbleRect.maxY
            )
        case .bottomCenter:
            tailRight = CGPoint(
                x: bubbleRect.midX - tailSize.width / 2,
                y: bubbleRect.maxY
            )
            tailTop = CGPoint(
                x: bubbleRect.midX,
                y: bubbleRect.maxY + tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.midX + tailSize.width / 2,
                y: bubbleRect.maxY
            )
        case .topLeft:
            tailRight = CGPoint(
                x: bubbleRect.minX + tailOffset - tailSize.width / 2,
                y: bubbleRect.minY
            )
            tailTop = CGPoint(
                x: bubbleRect.minX + tailOffset,
                y: bubbleRect.minY - tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.minX + tailOffset + tailSize.width / 2,
                y: bubbleRect.minY
            )
        case .topRight:
            tailRight = CGPoint(
                x: bubbleRect.maxX - tailOffset + tailSize.width / 2,
                y: bubbleRect.minY
            )
            tailTop = CGPoint(
                x: bubbleRect.maxX - tailOffset,
                y: bubbleRect.minY - tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.maxX - tailOffset - tailSize.width / 2,
                y: bubbleRect.minY
            )
        case .topCenter:
            tailRight = CGPoint(
                x: bubbleRect.midX - tailSize.width / 2,
                y: bubbleRect.minY
            )
            tailTop = CGPoint(
                x: bubbleRect.midX,
                y: bubbleRect.minY - tailSize.height
            )
            tailLeft = CGPoint(
                x: bubbleRect.midX + tailSize.width / 2,
                y: bubbleRect.minY
            )
        }
        path.move(to: tailRight)
        path.addArc(
            tangent1End: tailTop,
            tangent2End: tailLeft,
            radius: tailCornerRadius
        )
        path.addLine(to: tailLeft)
        path.closeSubpath()
        return path
    }
}
