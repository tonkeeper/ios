import UIKit
import TKUIKit

final class ManageTokensListSectionHeaderView: UICollectionReusableView {
  
  static var elementKind = "ManageTokensListSectionHeaderView"
  
  struct Configuration: Hashable {
    let title: NSAttributedString
    let caption: NSAttributedString?
    
    init(title: String,
         caption: String? = nil) {
      self.title = title.withTextStyle(.label1, color: .Text.primary)
      self.caption = caption?.withTextStyle(.body2, color: .Text.secondary)
    }
  }
  
  var configuration = Configuration(title: "Title", caption: nil) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let titleLabel = UILabel()
  let captionLabel = UILabel()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
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
    titleLabel.numberOfLines = 0
    captionLabel.numberOfLines = 0
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(captionLabel)
    setupConstraints()
  }
  
  private func setupConstraints() {
    captionLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.left.right.equalTo(self).inset(2)
      make.top.bottom.equalTo(self).inset(12)
    }
  }
  
  private func didUpdateConfiguration() {
    titleLabel.attributedText = configuration.title
    if let caption = configuration.caption {
      captionLabel.attributedText = caption
      captionLabel.isHidden = false
    } else {
      captionLabel.attributedText = nil
      captionLabel.isHidden = true
    }
  }
}
