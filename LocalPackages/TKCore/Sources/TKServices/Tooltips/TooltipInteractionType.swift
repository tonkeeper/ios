import Foundation

enum TooltipInteractionType {
    case hintContentTap
    case outsideTap
    case performedTargetAction
}

extension TooltipInteractionType: CustomStringConvertible {
    var description: String {
        switch self {
        case .hintContentTap:
            "hintContentTap"
        case .outsideTap:
            "outsideTap"
        case .performedTargetAction:
            "performedTargetAction"
        }
    }
}
