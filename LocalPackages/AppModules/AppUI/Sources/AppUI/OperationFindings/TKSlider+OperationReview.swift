import OperationReviewModels
import TKUIKit

public extension TKSlider.Appearance {
    /// Tinted by the review's worst finding; an info finding is never shown, so it leaves the slider as is.
    init(review: OperationReview?) {
        switch review?.severity {
        case .danger:
            self = .danger
        case .warning:
            self = .warning
        case .info, nil:
            self = .standart
        }
    }
}
