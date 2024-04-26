import UIKit
import TKUIKit
import SnapKit

final class ChartButtonsView: UIView, ConfigurableView {
  
  let containerView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .equalSpacing
    return stackView
  }()
  
  var buttons = [TKButton]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  struct Model {
    struct Button {
      let title: String
      let isSelected: Bool
      let tapAction: (() -> Void)?
    }
    
    let buttons: [Button]
  }
  
  func configure(model: Model) {
    containerView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    buttons = []
    model.buttons.forEach { buttonModel in
      let configuration: TKButton.Configuration = .configuration
      let button = TKButton(configuration: configuration)
      button.isSelected = buttonModel.isSelected
      button.isUserInteractionEnabled = !buttonModel.isSelected
      
      button.configuration.content.title = .plainString(buttonModel.title)
      button.configuration.action = { [unowned self] in
        guard !button.isSelected else { return }
        self.buttons.forEach {
          $0.isSelected = $0 === button
          $0.isUserInteractionEnabled = $0 !== button
        }
        buttonModel.tapAction?()
      }
      containerView.addArrangedSubview(button)
      buttons.append(button)
    }
  }
  
  private func setup() {
    addSubview(containerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.containerPadding)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 84
}

private extension UIEdgeInsets {
  static var containerPadding = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
}

private extension TKButton.Configuration {
  static var configuration: TKButton.Configuration {
    TKButton.Configuration(
      content: Content(),
      contentPadding: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16),
      padding: .zero,
      textStyle: .label2,
      textColor: .Button.secondaryForeground,
      backgroundColors: [
        .normal: .clear,
        .selected: .Button.secondaryBackground,
        .highlighted: .Button.secondaryBackgroundHighlighted
      ],
      cornerRadius: 18,
      action: nil
    )
  }
}
