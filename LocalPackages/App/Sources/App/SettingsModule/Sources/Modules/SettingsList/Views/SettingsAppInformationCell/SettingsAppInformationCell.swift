import UIKit
import TKUIKit
import Lottie

final class SettingsAppInformationCell: UICollectionViewCell {
  
  private let appNameLabel = UILabel()
  private let versionLabel = UILabel()
  private let diamondView = LottieAnimationView(name: "diamond.json", bundle: .module)
  private let stackView = UIStackView()
  
  struct Configuration: Hashable {
    let appName: String
    let version: String
  }
  
  var configuration = Configuration(appName: "", version: "") {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func didUpdateConfiguration() {
    appNameLabel.attributedText = configuration.appName
      .withTextStyle(
        .label2,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    
    versionLabel.attributedText = configuration.version
      .withTextStyle(
        .body3,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
  }
}

private extension SettingsAppInformationCell {
  func setup() {
    stackView.axis = .vertical
    stackView.addArrangedSubview(diamondView)
    stackView.addArrangedSubview(appNameLabel)
    stackView.addArrangedSubview(versionLabel)
    
    addSubview(stackView)
    
    diamondView.snp.makeConstraints { make in
      make.height.equalTo(46)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(
        UIEdgeInsets(
          top: 16,
          left: 0,
          bottom: 0,
          right: 0
        )
      ).priority(.required.advanced(by: -1))
    }
    
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapDiamond))
    diamondView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  @objc
  func didTapDiamond() {
    diamondView.play()
  }
}
