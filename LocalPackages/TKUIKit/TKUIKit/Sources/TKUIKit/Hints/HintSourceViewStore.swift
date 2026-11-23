import UIKit

@MainActor
final class HintSourceViewStore: ObservableObject {
    weak var view: UIView?
    /// Set by a `hintAnchor()` inside the label: the hint points there instead of at the whole label.
    weak var anchor: UIView?
}
