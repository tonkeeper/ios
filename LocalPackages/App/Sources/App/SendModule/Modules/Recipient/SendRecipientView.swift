import UIKit
import TKUIKit
import SnapKit

final class SendRecipientView: UIView {

  let recipientTextField = TKTextView()
  let pasteButton = TKHeaderButton(category: .tertiary)

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SendRecipientView {
  func setup() {
    backgroundColor = .Background.page
    
    pasteButton.configure(model: TKButton.Model(title: "Paste"))
    
    addSubview(recipientTextField)
    recipientTextField.rightItemsViews = [pasteButton]
    
    setupConstraints()
  }
  
  func setupConstraints() {
    recipientTextField.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).inset(16)
      make.left.right.equalTo(self).inset(16).priority(999)
    }
  }
}
