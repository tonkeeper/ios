import UIKit

public struct TKPopUpDetailsDescriptionItem: TKPopUp.Item {
    public let model: TKDetailsDescriptionView.Model
    public let bottomSpace: CGFloat

    public func getView() -> UIView {
        let view = TKDetailsDescriptionView()
        view.configure(model: model)
        return view
    }

    public init(model: TKDetailsDescriptionView.Model, bottomSpace: CGFloat) {
        self.model = model
        self.bottomSpace = bottomSpace
    }
}
