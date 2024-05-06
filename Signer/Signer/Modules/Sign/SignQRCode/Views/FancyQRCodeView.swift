import UIKit
import TKUIKit

final class FancyQRCodeView: UIView, ConfigurableView {
  
  var color: UIColor = UIColor(hex: "CAFF7A", alpha: 1) {
    didSet {
      qrCodeContainer.backgroundColor = color
      bottomPartView.backgroundColor = color
    }
  }
  
  let qrCodeContainer = UIView()
  let qrCodeImageViewContainer = UIView()
  let qrCodeImageView = UIImageView()
  let bottomPartView = UIView()
  let labelStackView = UIStackView()
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  let maskImageView = UIImageView(image: UIImage(named: "Rectangle"))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    bottomPartView.layoutIfNeeded()
    maskImageView.frame = bottomPartView.bounds
    qrCodeImageView.frame = qrCodeImageViewContainer.bounds
  }
  
  struct Model {
    let image: UIImage?
    let topString: String?
    let bottomString: String?
  }
  
  func configure(model: Model) {
    qrCodeImageView.image = model.image
    topLabel.text = model.topString?.uppercased()
    bottomLabel.text = model.bottomString?.uppercased()
    setNeedsLayout()
  }
}

private extension FancyQRCodeView {
  func setup() {
    labelStackView.axis = .vertical
    
    topLabel.textColor = .black
    topLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
    bottomLabel.textColor = .black
    bottomLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
    
    qrCodeContainer.backgroundColor = color
    qrCodeContainer.layer.cornerCurve = .continuous
    qrCodeContainer.layer.cornerRadius = 16
    qrCodeContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    
    bottomPartView.backgroundColor = color
    bottomPartView.mask = maskImageView
    
    qrCodeImageView.contentMode = .center

    addSubview(qrCodeContainer)
    qrCodeContainer.addSubview(qrCodeImageViewContainer)
    qrCodeImageViewContainer.addSubview(qrCodeImageView)
    addSubview(bottomPartView)
    bottomPartView.addSubview(labelStackView)
    labelStackView.addArrangedSubview(topLabel)
    labelStackView.addArrangedSubview(bottomLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    qrCodeContainer.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    qrCodeImageViewContainer.snp.makeConstraints { make in
      make.top.left.right.equalTo(qrCodeContainer).inset(24).priority(.high)
      make.bottom.equalTo(qrCodeContainer).priority(.high)
      make.height.equalTo(qrCodeImageViewContainer.snp.width)
    }

    bottomPartView.snp.makeConstraints { make in
      make.top.equalTo(qrCodeContainer.snp.bottom).offset(-1)
      make.left.right.equalTo(qrCodeContainer)
      make.height.equalTo(76)
      make.bottom.equalTo(self).priority(.high)
    }
    
    labelStackView.snp.makeConstraints { make in
      make.left.right.equalTo(bottomPartView).inset(24)
      make.top.equalTo(bottomPartView).offset(16)
      make.bottom.equalTo(bottomPartView).offset(-18).priority(.high)
    }
    
    topLabel.snp.makeConstraints { make in
      make.height.equalTo(20)
    }
    
    bottomLabel.snp.makeConstraints { make in
      make.height.equalTo(20)
    }
  }
}
