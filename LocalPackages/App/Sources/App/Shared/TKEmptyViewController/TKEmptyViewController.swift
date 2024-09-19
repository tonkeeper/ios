import UIKit
import TKUIKit

final class TKEmptyViewController: UIViewController {
  struct Model {
    struct Button {
      let title: String
      let action: () -> Void
    }
    let title: String
    let caption: String?
    let buttons: [Button]
  }
  
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  private let stackView = UIStackView()
  private let topStackView = UIStackView()
  private let buttonsStackView = UIStackView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    captionLabel.attributedText = model.caption?.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    
    buttonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let buttonsChunks = model.buttons.chunked(into: 2)
    buttonsChunks.forEach { chunk in
      let stackView = UIStackView()
      stackView.spacing = .interButtonsSpace
      chunk.forEach { buttonModel in
        let button = TKButton(
          configuration: .actionButtonConfiguration(category: .secondary, size: .medium)
        )
        button.configuration.content = .init(title: .plainString(buttonModel.title))
        button.configuration.action = buttonModel.action
        stackView.addArrangedSubview(button)
      }
      buttonsStackView.addArrangedSubview(stackView)
    }
  }
}

private extension TKEmptyViewController {
  func setup() {
    titleLabel.numberOfLines = 0
    captionLabel.numberOfLines = 0
    
    stackView.axis = .vertical
    
    topStackView.axis = .vertical
    topStackView.isLayoutMarginsRelativeArrangement = true
    topStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 32,
      bottom: 16,
      trailing: 32
    )
    
    buttonsStackView.alignment = .center
    buttonsStackView.axis = .vertical
    buttonsStackView.spacing = 8
    buttonsStackView.isLayoutMarginsRelativeArrangement = true
    buttonsStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 8,
      leading: 0,
      bottom: 32,
      trailing: 0
    )
    
    view.addSubview(stackView)
    
    topStackView.addArrangedSubview(titleLabel)
    topStackView.setCustomSpacing(4, after: titleLabel)
    topStackView.addArrangedSubview(captionLabel)
    
    stackView.addArrangedSubview(topStackView)
    stackView.addArrangedSubview(buttonsStackView)
    
    stackView.snp.makeConstraints { make in
      make.center.equalTo(self.view)
      make.top.left.greaterThanOrEqualTo(self.view)
      make.bottom.right.lessThanOrEqualTo(self.view)
    }
  }
}

private extension CGFloat {
  static let interButtonsSpace: CGFloat = 12
  static let titleBottomSpace: CGFloat = 4
  static let captionBottomSpace: CGFloat = 24
}
