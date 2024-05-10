import UIKit
import TKUIKit

final class TKBridgeWebHeaderView: UIView {

  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let blurView = TKBlurView()
  let contentView = UIView()
  let centerContainer = UIView()
  let closeButton = TKButton(configuration: .iconHeaderButtonConfiguration())
  let backButton = TKButton(configuration: .iconHeaderButtonConfiguration())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setTitle(_ title: String?) {
    let attributed = title?.withTextStyle(
      .h3,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byTruncatingTail
    )
    titleLabel.attributedText = attributed
  }
  
  func setSubtitle(_ subtitle: String, isSecured: Bool) {
    let subtitleResult = NSMutableAttributedString()
    if isSecured {
      let attachment = NSTextAttachment(image: .TKUIKit.Icons.Size12.lock)
      let attachmentString = NSMutableAttributedString(attachment: attachment)
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .center
      attachmentString.addAttributes(
        [.foregroundColor: UIColor.Text.secondary, .paragraphStyle: paragraphStyle],
        range: NSRange(
          location: 0,
          length: attachmentString.length
        )
      )
      subtitleResult.append(attachmentString)
      subtitleResult.append(NSAttributedString(string: " "))
    }
    
    let subtitle = subtitle.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .center,
      lineBreakMode: .byTruncatingTail
    )
    subtitleResult.append(subtitle)
    
    subtitleLabel.attributedText = subtitleResult
  }
}

private extension TKBridgeWebHeaderView {
  func setup() {
    addSubview(blurView)
    addSubview(contentView)
    contentView.addSubview(centerContainer)
    centerContainer.addSubview(titleLabel)
    centerContainer.addSubview(subtitleLabel)
    contentView.addSubview(closeButton)
    contentView.addSubview(backButton)
    
    closeButton.configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.close)
    backButton.configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.chevronLeft)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    blurView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide.snp.top)
      make.left.right.bottom.equalTo(self)
      make.height.equalTo(64)
    }
    
    centerContainer.snp.makeConstraints { make in
      make.centerX.centerY.equalTo(contentView)
      make.right.greaterThanOrEqualTo(closeButton)
      make.left.lessThanOrEqualTo(backButton)
    }
    
    closeButton.snp.makeConstraints { make in
      make.right.equalTo(contentView).offset(-8)
      make.centerY.equalTo(contentView)
    }
    
    backButton.snp.makeConstraints { make in
      make.left.equalTo(contentView).offset(8)
      make.centerY.equalTo(contentView)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.top.left.right.equalTo(centerContainer)
      make.width.greaterThanOrEqualTo(centerContainer)
    }
    
    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom)
      make.left.right.equalTo(centerContainer)
      make.bottom.equalTo(centerContainer)
      make.width.greaterThanOrEqualTo(centerContainer)
    }
  }
}
