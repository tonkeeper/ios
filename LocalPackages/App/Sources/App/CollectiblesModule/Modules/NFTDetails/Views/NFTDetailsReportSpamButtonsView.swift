import UIKit
import TKUIKit

final class NFTDetailsReportSpamButtonsView: UIView, ConfigurableView {

  struct Model {
    let buttonModels: [TKButton.Configuration]
  }

  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.buttonModels.forEach { configuration in
      let button = TKButton()
      button.configuration = configuration
      stackView.addArrangedSubview(button)
    }
  }

  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = 8
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
      make.top.equalTo(self).inset(8)
      make.left.right.equalTo(self).inset(16)
      make.bottom.equalTo(self).offset(-16)
    }
  }
}
