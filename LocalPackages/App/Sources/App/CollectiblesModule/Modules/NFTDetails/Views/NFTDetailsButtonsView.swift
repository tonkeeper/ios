import UIKit
import TKUIKit

final class NFTDetailsButtonsView: UIView, ConfigurableView {
  
  struct Model {
    let buttonViewModels: [NFTDetailsButtonView.Model]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.buttonViewModels.forEach { buttonViewModel in
      let button = NFTDetailsButtonView()
      button.configure(model: buttonViewModel)
      stackView.addArrangedSubview(button)
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(16)
      make.bottom.equalTo(self).offset(-16)
    }
  }
}
