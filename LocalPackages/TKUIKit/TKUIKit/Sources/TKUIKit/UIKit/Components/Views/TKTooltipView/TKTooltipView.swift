import SwiftUI
import UIKit

public struct TKTooltipView: View {
    public struct Configuration: Equatable {
        public let title: String
        public let badgeTitle: String?

        public init(title: String, badgeTitle: String? = nil) {
            self.title = title
            self.badgeTitle = badgeTitle
        }
    }

    public let configuration: Configuration?

    public init(configuration: Configuration?) {
        self.configuration = configuration
    }

    public var body: some View {
        Group {
            if let configuration {
                HStack(alignment: .top, spacing: 6) {
                    if let badgeTitle = configuration.badgeTitle, !badgeTitle.isEmpty {
                        Text(badgeTitle.uppercased())
                            .foregroundColor(Color(UIColor.Accent.blue))
                            .textStyle(.body4)
                            .padding(.top, 2.5)
                            .padding(.bottom, 3.5)
                            .padding(.horizontal, 5)
                            .background(Color(UIColor.Constant.white))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(configuration.title)
                        .foregroundColor(Color(UIColor.Constant.white))
                        .textStyle(.label2)
                        .lineLimit(1)
                }
                .padding(.top, 10)
                .padding(.leading, 14)
                .padding(.bottom, 10)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    TooltipBubbleShape()
                        .fill(Color(UIColor.Accent.blue))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
            } else {
                Color.clear
            }
        }
    }
}

private struct TooltipBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, rect.height - Metrics.tipHeight)
        )

        let bodyPath = UIBezierPath(
            roundedRect: bodyRect,
            cornerRadius: Metrics.cornerRadius
        )

        let halfApexRadius = Metrics.tipApexRadius / 2
        let apexLeftPoint = CGPoint(x: Metrics.tipCenterX - halfApexRadius, y: rect.maxY - halfApexRadius)
        let apexPoint = CGPoint(x: Metrics.tipCenterX, y: rect.maxY)
        let apexRightPoint = CGPoint(x: Metrics.tipCenterX + halfApexRadius, y: rect.maxY - halfApexRadius)

        bodyPath.move(to: CGPoint(x: Metrics.tipMinX, y: bodyRect.maxY))
        bodyPath.addLine(to: apexLeftPoint)
        bodyPath.addQuadCurve(to: apexRightPoint, controlPoint: apexPoint)
        bodyPath.addLine(to: CGPoint(x: Metrics.tipMaxX, y: bodyRect.maxY))

        return Path(bodyPath.cgPath)
    }
}

private enum Metrics {
    static let cornerRadius: CGFloat = 10
    static let tipHeight: CGFloat = 6
    static let tipApexRadius: CGFloat = 4
    static let tipMinX: CGFloat = 18
    static let tipCenterX: CGFloat = 24
    static let tipMaxX: CGFloat = 30
}
