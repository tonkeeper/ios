import UIKit
import TKUIKit

struct TransactionConfirmationHeaderImageItem: TKPopUp.Item {
  func getView() -> UIView {
    TransactionConfirmationHeaderImageItemView(configuration: configuration)
  }
  
  let configuration: TransactionConfirmationHeaderImageItemView.Configuration
  let bottomSpace: CGFloat
  
  init(configuration: TransactionConfirmationHeaderImageItemView.Configuration,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class TransactionConfirmationHeaderImageItemView: UIView {
  struct Configuration {
    let image: TKImage
    let corners: TKImageView.Corners
    let badgeImage: TKImage?
  }
  
  let configuration: Configuration
  
  let iconView = TKListItemIconView()
  
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(iconView)
    
    var badge: TKListItemIconView.Configuration.Badge?
    if let badgeImage = configuration.badgeImage {
      badge = TKListItemIconView.Configuration.Badge(
        configuration: TKListItemBadgeView.Configuration(
          item: .image(badgeImage),
          size: .xlarge,
          backgroundColor: .Background.page
        ),
        position: .bottomRight
      )
    }
    
    iconView.configuration = TKListItemIconView.Configuration(
      content: .image(
        TKImageView.Model(
          image: configuration.image,
          size: .size(CGSize(width: 96, height: 96)),
          corners: configuration.corners
        )
      ),
      alignment: .center,
      size: CGSize(width: 96, height: 96),
      badge: badge
    )
    
    iconView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.center.equalTo(self)
      make.width.height.equalTo(96)
    }
  }
}
