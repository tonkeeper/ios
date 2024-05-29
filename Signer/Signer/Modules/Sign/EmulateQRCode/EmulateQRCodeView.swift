import UIKit
import TKUIKit
import TKQRCode
import SnapKit

final class EmulateQRCodeView: UIView, ConfigurableView {
  
  let containerView = UIView()
  let scrollView = UIScrollView()
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 32,
      trailing: 16
    )
    return view
  }()
  let qrCodeImageView = TKQRCodeImageView(frame: .zero)
  let qrCodeContainer = UIView()
  let closeButton = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let qrCode: QRCode?
    let closeButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    qrCodeImageView.setQRCode(model.qrCode)
    closeButton.configuration = model.closeButtonConfiguration
  }
}

private extension EmulateQRCodeView {
  func setup() {
    qrCodeContainer.backgroundColor = .white
    qrCodeContainer.layer.cornerRadius = 16
    
    qrCodeImageView.contentMode = .scaleAspectFit
    
    addSubview(scrollView)
    scrollView.addSubview(containerView)
    containerView.addSubview(titleDescriptionView)
    containerView.addSubview(qrCodeContainer)
    containerView.addSubview(closeButton)
    qrCodeContainer.addSubview(qrCodeImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    containerView.snp.makeConstraints { make in
      make.top.bottom.equalTo(scrollView)
      make.left.equalTo(scrollView).offset(16)
      make.right.equalTo(scrollView).offset(-16)
      make.width.equalTo(scrollView).inset(16).priority(.high)
    }
    
    titleDescriptionView.snp.makeConstraints { make in
      make.top.left.right.equalTo(containerView)
      make.width.equalTo(scrollView).inset(16).priority(.high)
    }
    
    qrCodeContainer.snp.makeConstraints { make in
      make.top.equalTo(titleDescriptionView.snp.bottom)
      make.left.right.equalTo(containerView)
      make.height.equalTo(qrCodeContainer.snp.width)
    }
    
    qrCodeImageView.snp.makeConstraints { make in
      make.edges.equalTo(qrCodeContainer).inset(16)
    }
    
    closeButton.snp.makeConstraints { make in
      make.top.equalTo(qrCodeImageView.snp.bottom).offset(32)
      make.left.right.equalTo(containerView)
      make.bottom.equalTo(containerView).offset(-16)
    }
  }
}
