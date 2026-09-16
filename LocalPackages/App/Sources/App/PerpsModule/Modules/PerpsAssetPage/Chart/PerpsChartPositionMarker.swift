import TKUIKit
import UIKit

struct PerpsChartPositionMarker: Identifiable, Equatable {
    enum Kind: Hashable {
        case takeProfit
        case entry
        case stopLoss
        case liquidation
        case currentPrice
    }

    enum Alignment: Equatable {
        case left
        case right
    }

    enum Direction: Equatable {
        case up
        case down
    }

    let kind: Kind
    let price: Double
    /// Only meaningful for `.currentPrice`, where it drives the up/down color.
    let direction: Direction?

    init(kind: Kind, price: Double, direction: Direction? = nil) {
        self.kind = kind
        self.price = price
        self.direction = direction
    }

    var id: Kind {
        kind
    }

    var title: String {
        kind.title
    }

    var alignment: Alignment {
        kind.alignment
    }

    var color: TKColor {
        kind.color(direction: direction)
    }

    func backgroundColor(resolvedTheme: TKResolvedTheme) -> UIColor {
        UIColor(color.resolve(resolvedTheme.palette)).composited(
            over: UIColor(TKColor.backgroundPage.resolve(resolvedTheme.palette)),
            alpha: 0.16
        )
    }
}

extension UIColor {
    /// Opaque result of laying `self` at `alpha` over `background`, resolved per
    /// trait so it tracks light/dark like the source tokens.
    func composited(over background: UIColor, alpha: CGFloat) -> UIColor {
        UIColor { traits in
            let top = self.resolvedColor(with: traits)
            let base = background.resolvedColor(with: traits)
            var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
            base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            return UIColor(
                red: tr * alpha + br * (1 - alpha),
                green: tg * alpha + bg * (1 - alpha),
                blue: tb * alpha + bb * (1 - alpha),
                alpha: 1
            )
        }
    }
}

extension PerpsChartPositionMarker.Kind {
    var title: String {
        switch self {
        case .takeProfit: return "TP"
        case .entry: return "Entry"
        case .stopLoss: return "SL"
        case .liquidation: return "Liq"
        case .currentPrice: return ""
        }
    }

    var alignment: PerpsChartPositionMarker.Alignment {
        self == .currentPrice ? .right : .left
    }

    func color(direction: PerpsChartPositionMarker.Direction?) -> TKColor {
        switch self {
        case .takeProfit: return .accentBlue
        case .entry: return .accentPurple
        case .stopLoss: return .accentOrange
        case .liquidation: return .accentRed
        case .currentPrice: return direction == .down ? .accentRed : .accentGreen
        }
    }
}
