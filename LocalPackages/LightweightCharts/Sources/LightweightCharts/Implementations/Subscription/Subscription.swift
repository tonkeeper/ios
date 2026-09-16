import Foundation

enum Subscription: String {
    case click = "ClickSubscriber"
    case dblClick = "DblClickSubscriber"
    case crosshairMove = "CrosshairMoveSubscriber"
    case dataChanged = "DataChangedSubscriber"
    case visibleTimeRangeChange = "VisibleTimeRangeChangeSubscriber"
    case visibleLogicalRangeChange = "VisibleLogicalRangeChangeSubscriber"
    case timeScaleSizeChange = "TimeScaleSizeChangeSubscriber"

    var jsRepresentation: String {
        switch self {
        case .click:
            return "Click"
        case .dblClick:
            return "DblClick"
        case .crosshairMove:
            return "CrosshairMove"
        case .dataChanged:
            return "DataChanged"
        case .visibleTimeRangeChange:
            return "VisibleTimeRangeChange"
        case .visibleLogicalRangeChange:
            return "VisibleLogicalRangeChange"
        case .timeScaleSizeChange:
            return "SizeChange"
        }
    }
}
