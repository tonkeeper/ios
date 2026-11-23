import UIKit

public extension UIInterfaceOrientationMask {
    @MainActor static let tkDefault: UIInterfaceOrientationMask =
        UIDevice.current.model.hasPrefix("iPad") ? .all : .portrait
}
