import UIKit
import TKUIKit
import TKLocalize

final class SettingsDeleteWarningViewController: UIViewController, TKBottomSheetScrollContentViewController {
  
  enum Delete {
    case wallet(walletName: NSAttributedString)
    case all
  }
  
  var didTapSignOut: (() -> Void)?
  var didTapBackup: (() -> Void)?
  
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
  
  private let delete: Delete
  
  init(delete: Delete) {
    self.delete = delete
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
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
    titleLabel.attributedText = TKLocales.SignOutWarning.title.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    stackView.addArrangedSubview(titleLabel)
    stackView.setCustomSpacing(4, after: titleLabel)
    
    let captionLabel = UILabel()
    captionLabel.numberOfLines = 0
    captionLabel.attributedText = TKLocales.SignOutWarning.caption.withTextStyle(
      .body1,
      color: .Text.secondary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    stackView.addArrangedSubview(captionLabel)
    stackView.setCustomSpacing(16, after: captionLabel)
    
    let contentView = SettingsDeleteWarningContentView()
    contentView.tickText = {
      switch delete {
      case .wallet(let walletName):
        let textAttributedString = TKLocales.SignOutWarning.tickDescription.withTextStyle(
          .body1,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
        let resultAttributedString = NSMutableAttributedString(attributedString: textAttributedString)
        resultAttributedString.append(NSAttributedString(string: " "))
        resultAttributedString.append(walletName)
        return resultAttributedString
      case .all:
        return TKLocales.SignOutWarning.tickDescription.withTextStyle(
          .body1,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
      }
    }()
    stackView.addArrangedSubview(contentView)
    stackView.setCustomSpacing(16, after: contentView)
    
    let signoutButton = TKButton()
    var signoutButtonConfiguration: TKButton.Configuration = .actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    signoutButtonConfiguration.isEnabled = false
    signoutButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.signOut))
    signoutButtonConfiguration.action = { [didTapSignOut] in
      didTapSignOut?()
    }
    signoutButton.configuration = signoutButtonConfiguration
    stackView.addArrangedSubview(signoutButton)
    
    stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(16)))
    
    contentView.didToggle = { isSelected in
      signoutButton.configuration.isEnabled = isSelected
    }
    contentView.didTapBackup = { [didTapBackup] in
      didTapBackup?()
    }
    
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
