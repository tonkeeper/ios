import UIKit
import TKUIKit

final class HistoryEventDetailsListContainerItemEncryptedCommenValueView: UIView {
  enum Configuration: TKListContainerItemValue {
    func getView() -> UIView {
      let view = HistoryEventDetailsListContainerItemEncryptedCommenValueView()
      view.configuration = self
      return view
    }
    
    case encrypted(text: String)
    case decrypted(text: String?)
  }
  
  var configuration: Configuration = .decrypted(text: nil) {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let textLabel = UILabel()
  private let spoilerView = TKSpoilerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    textLabel.numberOfLines = 0
    
    spoilerView.spoilerColor = .Text.primary
    
    addSubview(textLabel)
    addSubview(spoilerView)
    
    textLabel.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    spoilerView.snp.makeConstraints { make in
      make.edges.equalTo(textLabel)
    }
  }
  
  private func didUpdateConfiguration() {
    switch configuration {
    case .encrypted(let text):
      let count = text.count / 2 - 64
      let updatedText = String(repeating: "0", count: count)
      textLabel.alpha = 0
      textLabel.attributedText = updatedText.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .right,
        lineBreakMode: .byWordWrapping
      )
      spoilerView.isOn = true
    case .decrypted(let text):
      textLabel.alpha = 1
      textLabel.attributedText = text?.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .right,
        lineBreakMode: .byWordWrapping
      )
      spoilerView.isOn = false
    }
  }
}
