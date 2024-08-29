import UIKit
import TKUIKit

protocol TKListContainerItem {
  var isHighlightable: Bool { get }
  var tapAction: (() -> Void)? { get }
  
  func getView() -> UIView
}

final class TKListContainerView: UIView {
  
  struct Configuration {
    let items: [TKListContainerItem]
  }
  
  var configuration: Configuration? {
    didSet {
      setup(with: configuration)
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 16
    return view
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(backgroundView)
    backgroundView.addSubview(stackView)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(backgroundView).inset(8)
      make.left.right.equalTo(backgroundView)
    }
  }
  
  private func setup(with configuration: Configuration?) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    guard let configuration else { return }
    configuration.items.forEach { item in
      let contentView = item.getView()
      contentView.isUserInteractionEnabled = false
      let itemView = TKListContainerItemView()
      itemView.setContentView(contentView)
      itemView.isHighlightable = item.isHighlightable
      itemView.addAction(UIAction(handler: { _ in
        item.tapAction?()
      }), for: .touchUpInside)
      stackView.addArrangedSubview(itemView)
    }
  }
}
