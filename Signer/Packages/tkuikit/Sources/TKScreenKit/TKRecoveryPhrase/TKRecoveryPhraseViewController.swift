import UIKit
import TKUIKit

public final class TKRecoveryPhraseViewController: GenericViewViewController<TKRecoveryPhraseView> {
  
  public var didTapCopy: (() -> Void)?
  
  public func configure(with model: TKRecoveryPhraseView.Model) {
    customView.configure(model: model)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
}

private extension TKRecoveryPhraseViewController {
  func setup() {
    customView.copyButton.configure(
      model: TKButtonControl<ButtonTitleContentView>.Model(
        contentModel: ButtonTitleContentView.Model(title: "Copy"),
        action: { [weak self] in
          self?.didTapCopy?()
        }
      )
    )
  }
}
