import UIKit
import TKUIKit

final class SettingsListSectionFooterView: UICollectionReusableView {
  
  static var elementKind = "SettingsListSectionFooterView"
  
  struct Configuration: Hashable {
    let text: NSAttributedString
    
    init(text: String) {
      self.text = text.withTextStyle(.body2, color: .Text.secondary)
    }
  }
  
  var configuration = Configuration(text: "Description") {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let textLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    textLabel.numberOfLines = 0
    
    addSubview(textLabel)
    setupConstraints()
  }
  
  private func setupConstraints() {
    textLabel.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 12, left: 1, bottom: 16, right: 1))
    }
  }
  
  private func didUpdateConfiguration() {
    textLabel.attributedText = configuration.text
  }
}
