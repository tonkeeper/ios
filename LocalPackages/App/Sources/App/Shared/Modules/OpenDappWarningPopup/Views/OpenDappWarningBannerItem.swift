import TKUIKit
import UIKit

struct OpenDappWarningBannerItem: TKPopUp.Item {
    let configuration: OpenDappWarningBannerView.Model
    let bottomSpace: CGFloat

    func getView() -> UIView {
        let view = OpenDappWarningBannerView()
        view.configure(model: configuration)
        return view
    }
}
