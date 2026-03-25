import UIKit

open class GenericViewViewController<View: UIView>: BasicViewController {
    public var customView: View {
        self.view as! View
    }

    override open func loadView() {
        view = View()
    }
}
