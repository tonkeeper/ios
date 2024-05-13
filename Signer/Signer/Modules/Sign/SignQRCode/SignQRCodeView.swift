import UIKit
import TKUIKit
import SnapKit

final class SignQRCodeView: UIView, ConfigurableView {
  
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
  let qrCodeView = TKFancyQRCodeView()
  let doneButton = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let qrCodeModel: TKFancyQRCodeView.Model
    let doneButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    doneButton.configuration = model.doneButtonConfiguration
    qrCodeView.configure(model: model.qrCodeModel)
  }
}

private extension SignQRCodeView {
  func setup() {
    addSubview(scrollView)
    scrollView.addSubview(containerView)
    containerView.addSubview(titleDescriptionView)
    containerView.addSubview(qrCodeView)
    containerView.addSubview(doneButton)
    
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
    
    qrCodeView.snp.makeConstraints { make in
      make.top.equalTo(titleDescriptionView.snp.bottom)
      make.left.right.equalTo(containerView)
    }
    
    doneButton.snp.makeConstraints { make in
      make.top.equalTo(qrCodeView.snp.bottom).offset(32)
      make.left.right.equalTo(containerView)
      make.bottom.equalTo(containerView).offset(-16)
    }
//    containerView.snp.makeConstraints { make in
//      make.edges.equalTo(self)
//    }
//    
//    qrCodeView.snp.makeConstraints { make in
//      make.top.equalTo(containerView)
//      make.left.right.equalTo(containerView).inset(16).priority(.high)
//      make.bottom.equalTo(containerView).priority(.high)
//    }
  }
}
