import UIKit
import TKUIKit

final class BuySellListSegmentedControl: UIControl, ConfigurableView {
  
  var didSelectTab: ((Int) -> Void)?
  
  struct Model {
    let tabs: [String]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    model.tabs.enumerated().forEach { index, tab in
      let tabView = BuySellListSegmentedControlTabView()
      tabView.configure(model: BuySellListSegmentedControlTabView.Model(title: tab))
      tabView.addAction(UIAction(handler: { [weak self] _ in
        self?.selectedIndex = index
        self?.didSelectTab?(index)
      }), for: .touchUpInside)
      stackView.addArrangedSubview(tabView)
    }
    updateSelectedIndex(0, animated: false)
    selectedIndex = 0
  }
  
  var selectedIndex = 0 {
    didSet {
      updateSelectedIndex(selectedIndex, animated: true)
    }
  }
  
  private let stackView = UIStackView()
  private let backgroundView = UIView()
  private let selectionView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func updateSelectedIndex(_ index: Int, animated: Bool) {
    guard stackView.arrangedSubviews.count > index else { return }
    let view = stackView.arrangedSubviews[index]
    selectionView.snp.remakeConstraints { make in
      make.edges.equalTo(view)
    }
    if animated {
      UIView.animate(withDuration: 0.2) {
        self.layoutIfNeeded()
      }
    }
  }
  
  private func setup() {
    
    selectionView.layer.cornerRadius = 16
    selectionView.layer.cornerCurve = .continuous
    selectionView.backgroundColor = .Button.tertiaryBackground
    
    backgroundView.layer.cornerRadius = 20
    backgroundView.layer.cornerCurve = .continuous
    backgroundView.backgroundColor = .Background.content
    
    addSubview(backgroundView)
    addSubview(selectionView)
    addSubview(stackView)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(4)
    }
  }
}

private final class BuySellListSegmentedControlTabView: UIControl, ConfigurableView {
  
  struct Model {
    let title: String
  }
  
  func configure(model: Model) {
    label.attributedText = model.title.withTextStyle(
      .label2,
      color: .Button.secondaryForeground,
      alignment: .center,
      lineBreakMode: .byTruncatingTail
    )
  }
  
  override var isHighlighted: Bool {
    didSet {
      label.alpha = isHighlighted ? 0.64 : 1
    }
  }
  
  let label = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(label)

    label.snp.makeConstraints { make in
      make.top.equalTo(self).offset(6)
      make.left.equalTo(self).offset(12)
      make.bottom.equalTo(self).offset(-6)
      make.right.equalTo(self).offset(-12)
    }
  }
}
