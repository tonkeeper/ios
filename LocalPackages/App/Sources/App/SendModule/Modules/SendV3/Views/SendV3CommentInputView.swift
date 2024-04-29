import UIKit
import TKUIKit
import SnapKit

final class SendV3CommentInputView: UIView {
  
  let commentTextField = TKTextField(
    textFieldInputView: TKTextFieldInputView(
      textInputControl: TKTextInputTextViewControl()
    )
  )
  
  let descriptionLabel = UILabel()
  let descriptionContainer = UIView()
  
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
  
  private func setup() {
    descriptionLabel.numberOfLines = 0
    
    addSubview(stackView)
    descriptionContainer.addSubview(descriptionLabel)
    
    stackView.addArrangedSubview(commentTextField)
    stackView.addArrangedSubview(descriptionContainer)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    descriptionLabel.snp.makeConstraints { make in
      make.height.greaterThanOrEqualTo(20)
      make.top.equalTo(descriptionContainer).inset(12)
      make.bottom.equalTo(descriptionContainer).inset(16)
      make.left.right.equalTo(descriptionContainer)
    }
    
//    descriptionContainer
  }
}
