import UIKit
import TKUIKit
import SnapKit

final class SendCommentView: UIView {
  
  let scrollView = TKUIScrollView()
  let commentTextField = TKTextView()
  let descriptionLabel = UILabel()
  let pasteButton = TKHeaderButton(category: .tertiary)
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SendCommentView {
  func setup() {
    backgroundColor = .Background.page
    
    pasteButton.configure(model: TKButton.Model(title: "Paste"))
    commentTextField.rightItemsViews = [pasteButton]
    
    descriptionLabel.numberOfLines = 0
    
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    stackView.addArrangedSubview(commentTextField)
    stackView.setCustomSpacing(.commentTextFieldBottomPadding, after: commentTextField)
    stackView.addArrangedSubview(descriptionLabel)
    stackView.setCustomSpacing(.descriptionBottomPadding, after: descriptionLabel)
   
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.top.equalTo(scrollView).priority(.high)
    }
  }
}

private extension CGFloat {
  static let commentTextFieldBottomPadding: CGFloat = 12
  static let descriptionBottomPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static var contentPadding = UIEdgeInsets(
    top: 0,
    left: 16,
    bottom: 0,
    right: 16
  )
}
