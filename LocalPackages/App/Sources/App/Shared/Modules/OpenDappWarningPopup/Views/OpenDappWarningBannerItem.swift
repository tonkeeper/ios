import UIKit
import TKUIKit

struct OpenDappWarningBannerItem: TKPopUp.Item {
  let configuration: OpenDappWarningBannerView.Model
  let bottomSpace: CGFloat
  
  func getView() -> UIView {
    let view = OpenDappWarningBannerView()
    view.configure(model: configuration)
    return view
  }
  
  init(configuration: OpenDappWarningBannerView.Model,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}
