import UIKit
import TKUIKit

final class BackupWarningListView: TKView {
  
  var items = [String]() {
    didSet {
      stackView.subviews.forEach { $0.removeFromSuperview() }
      let itemViews = items.map {
        let view = BackupWarningListItemView()
        view.label.attributedText = $0.withTextStyle(
          .body2,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
        return view
      }
      itemViews.forEach {
        stackView.addArrangedSubview($0)
      }
    }
  }
  
  private let stackView = UIStackView()
  
  override func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    
    stackView.axis = .vertical
    
    addSubview(stackView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(12)
      make.left.right.equalTo(self).inset(12)
    }
  }
}

private final class BackupWarningListItemView: TKView {
  
  private let dotLabel = UILabel()
  let label = UILabel()
  
  override func setup() {
    
    dotLabel.attributedText = "\u{2022}".withTextStyle(
      .body2,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    label.numberOfLines = 0
    
    addSubview(dotLabel)
    addSubview(label)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    dotLabel.snp.makeConstraints { make in
      make.top.equalTo(self).inset(8)
      make.left.equalTo(self)
    }
    label.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(8)
      make.left.equalTo(dotLabel.snp.right).offset(8)
      make.right.equalTo(self)
    }
  }
}
