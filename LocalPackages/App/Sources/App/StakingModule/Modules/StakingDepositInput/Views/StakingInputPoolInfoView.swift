import UIKit
import TKUIKit

final class StakingInputPoolInfoView: UIControl, ConfigurableView {
  
  override var isHighlighted: Bool {
    didSet {
      hightlightView.isHighlighted = isHighlighted
    }
  }
  
  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.cornerRadius = 16
    view.layer.masksToBounds = true
    return view
  }()
  private let hightlightView = TKHighlightView()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    return stackView
  }()
  
  enum Model {
    case listItem(TKUIListItemView.Configuration)
    case text(NSAttributedString)
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    switch model {
    case .listItem(let configuration):
      let view = TKUIListItemView()
      view.configure(configuration: configuration)
      stackView.addArrangedSubview(view)
      stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
        top: 16,
        leading: 16,
        bottom: 16,
        trailing: 16
      )
      isUserInteractionEnabled = true
    case .text(let string):
      let label = UILabel()
      label.numberOfLines = 0
      label.attributedText = string
      stackView.addArrangedSubview(label)
      stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
        top: 8,
        leading: 16,
        bottom: 8,
        trailing: 16
      )
      isUserInteractionEnabled = false
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    stackView.isLayoutMarginsRelativeArrangement = true
    
    containerView.isUserInteractionEnabled = false
    
    addSubview(containerView)
    containerView.addSubview(hightlightView)
    containerView.addSubview(stackView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    hightlightView.snp.makeConstraints { make in
      make.edges.equalTo(containerView)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(containerView)
    }
  }
}
