import UIKit
import TKUIKit

final class BalanceHeaderBalanceStatusView: UIControl {
  
  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  struct Configuration {
    enum State {
      case address(String, tags: [TKTagView.Configuration])
      case updated(String)
      case connection(BalanceHeaderBalanceConnectionStatusView.Model)
    }
    
    let state: State
    let action: (() -> Void)?
  }
  
  var configuration = Configuration(state: .address("", tags: []), action: nil) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let stackView = UIStackView()
  private let labelTagsStackView = UIStackView()
  private let label = UILabel()
  private let connectionView = BalanceHeaderBalanceConnectionStatusView()
  private let tagsContainer = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    stackView.isUserInteractionEnabled = false
    stackView.axis = .vertical
    stackView.alignment = .center
    
    labelTagsStackView.axis = .horizontal
    labelTagsStackView.alignment = .center
    
    addSubview(stackView)
    stackView.addArrangedSubview(labelTagsStackView)
    labelTagsStackView.addArrangedSubview(label)
    labelTagsStackView.addArrangedSubview(tagsContainer)
    labelTagsStackView.addArrangedSubview(connectionView)
    
    setupConstraints()
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action?()
    }), for: .touchUpInside)
    
    didUpdateConfiguration()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    tagsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    switch configuration.state {
    case .address(let string, let tags):
      tagsContainer.isHidden = tags.isEmpty
      connectionView.isHidden = true
      label.isHidden = false
      label.attributedText = string.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
      tags.forEach {
        let view = TKTagView()
        view.configuration = $0
        tagsContainer.addArrangedSubview(view)
      }
    case .updated(let string):
      tagsContainer.isHidden = true
      connectionView.isHidden = true
      label.isHidden = false
      label.attributedText = string.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    case .connection(let model):
      tagsContainer.isHidden = true
      label.isHidden = true
      connectionView.isHidden = false
      connectionView.configure(model: model)
    }
  }
}
