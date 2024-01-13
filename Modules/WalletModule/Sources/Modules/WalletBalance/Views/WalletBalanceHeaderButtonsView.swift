import UIKit
import TKUIKit

final class WalletBalanceHeaderButtonsView: UIView, ConfigurableView {
  
  let dividerView = TKDividerBackgroundView()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let configuration: TKUIIconButton.Model
      let isEnabled: Bool
      let action: () -> Void
      
      init(configuration: TKUIIconButton.Model, 
           isEnabled: Bool = true,
           action: @escaping () -> Void) {
        self.configuration = configuration
        self.isEnabled = isEnabled
        self.action = action
      }
    }
    let buttons: [Button]
  }
  
  func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    let buttons = model.buttons.map {
      let button = TKUIIconButton()
      button.configure(model: $0.configuration)
      button.isEnabled = $0.isEnabled
      button.addTapAction($0.action)
      return button
    }
    
    let rows = buttons
      .map { $0 as UIView }
      .chunked(into: 3)
      .map { row in
        if row.count < 3 {
          let diff = 3 - row.count
          let emptyViews = (0..<diff).map { _ in UIView() }
          return row + emptyViews
        } else {
          return row
        }
      }
    
    rows.forEach { row in
      let rowStackView = UIStackView()
      rowStackView.distribution = .fillEqually
      
      row.forEach {
        rowStackView.addArrangedSubview($0)
      }
      
      stackView.addArrangedSubview(rowStackView)
    }
  }
}

private extension WalletBalanceHeaderButtonsView {
  func setup() {
    addSubview(dividerView)
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    dividerView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: NSDirectionalEdgeInsets.padding.top),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: NSDirectionalEdgeInsets.padding.leading),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -NSDirectionalEdgeInsets.padding.bottom),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -NSDirectionalEdgeInsets.padding.trailing),
      
      dividerView.topAnchor.constraint(equalTo: stackView.topAnchor),
      dividerView.leftAnchor.constraint(equalTo: stackView.leftAnchor),
      dividerView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
      dividerView.rightAnchor.constraint(equalTo: stackView.rightAnchor)
    ])
  }
}

private extension NSDirectionalEdgeInsets {
  static var padding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 16,
    bottom: 20,
    trailing: 16)
}

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}
