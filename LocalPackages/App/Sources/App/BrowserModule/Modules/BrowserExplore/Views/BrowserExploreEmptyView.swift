import UIKit
import TKUIKit
import SnapKit

final class BrowserExploreEmptyView: TKView, ConfigurableView {
  
  let titleLabel = UILabel()
  let captionLabel = UILabel()
  let button = TKButton()
  let contentView = UIView()
  
  override func setup() {
    super.setup()
    
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    
    titleLabel.numberOfLines = 0
    captionLabel.numberOfLines = 0
    
    addSubview(contentView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(captionLabel)
    contentView.addSubview(button)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    contentView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(20)
      make.left.bottom.right.equalTo(self).inset(24)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.left.right.equalTo(contentView)
    }
    
    captionLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom).offset(4)
      make.left.right.equalTo(contentView)
    }
    
    button.snp.makeConstraints { make in
      make.top.equalTo(captionLabel.snp.bottom).offset(16)
      make.left.bottom.equalTo(contentView)
      make.right.lessThanOrEqualTo(contentView)
    }
  }
  
  struct Model {
    let title: NSAttributedString
    let caption: NSAttributedString
    let button: TKButton.Configuration
    
    init(
      title: String,
      caption: String,
      button: TKButton.Configuration
    ) {
      self.title = title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
      self.caption = caption.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
      self.button = button
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    captionLabel.attributedText = model.caption
    button.configuration = model.button
  }
}
