import UIKit
import TKUIKit
import TKLocalize

final class BackupWarningViewController: UIViewController, TKBottomSheetScrollContentViewController {
  
  var didTapContinue: (() -> Void)?
  var didTapCancel: (() -> Void)?
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    nil
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    return stackView.systemLayoutSizeFitting(
      CGSize(width: width - 32, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    ).height
  }
  
  let scrollView = UIScrollView()
  let stackView = UIStackView()
  let listView = BackupWarningListView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  private func setup() {
    stackView.axis = .vertical
    
    view.addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    let titleLabel = UILabel()
    titleLabel.numberOfLines = 0
    titleLabel.attributedText = TKLocales.Backup.Warning.title.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    stackView.addArrangedSubview(titleLabel)
    stackView.setCustomSpacing(4, after: titleLabel)
    
    let captionLabel = UILabel()
    captionLabel.numberOfLines = 0
    captionLabel.attributedText = TKLocales.Backup.Warning.caption.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    stackView.addArrangedSubview(captionLabel)
    stackView.setCustomSpacing(32, after: captionLabel)
    
    listView.items = [
      TKLocales.Backup.Warning.List.item1,
      TKLocales.Backup.Warning.List.item2,
      TKLocales.Backup.Warning.List.item3
    ]
    
    stackView.addArrangedSubview(listView)
    stackView.setCustomSpacing(32, after: listView)
    
    let continueButton = TKButton()
    var continueButtonConfiguration: TKButton.Configuration = .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.continueAction))
    continueButtonConfiguration.action = { [didTapContinue] in
      didTapContinue?()
    }
    continueButton.configuration = continueButtonConfiguration
    stackView.addArrangedSubview(continueButton)
    stackView.setCustomSpacing(16, after: continueButton)
    
    let cancelButton = TKButton()
    var cancelButtonConfiguration: TKButton.Configuration = .actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    cancelButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.cancel))
    cancelButtonConfiguration.action = { [didTapCancel] in
      didTapCancel?()
    }
    cancelButton.configuration = cancelButtonConfiguration
    stackView.addArrangedSubview(cancelButton)
    
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(16)))
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    
    stackView.snp.makeConstraints { make in
      make.width.equalTo(scrollView).offset(-32)
      make.left.right.equalTo(scrollView).inset(16)
      make.top.equalTo(scrollView)
      make.bottom.equalTo(scrollView)
    }
  }
}
