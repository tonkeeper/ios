import UIKit
import TKUIKit

struct HistoryEventDetailsNFTCollectionComponent: TKPopUp.Item {
  func getView() -> UIView {
    let view = HistoryEventDetailsNFTCollectionView(
      configuration: configuration
    )
    return view
  }
  
  private let configuration: HistoryEventDetailsNFTCollectionView.Configuration
  public let bottomSpace: CGFloat
  
  init(configuration: HistoryEventDetailsNFTCollectionView.Configuration,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class HistoryEventDetailsNFTCollectionView: UIView {
  
  struct Configuration {
    let name: String
    let isVerified: Bool
  }
  
  private let configuration: Configuration
  
  private let stackView = UIStackView()

  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    stackView.axis = .horizontal
    stackView.spacing = 4
    stackView.alignment = .center
    
    addSubview(stackView)
    
    setupConstraints()
    setupConfiguration()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.centerX.equalTo(self)
      make.left.greaterThanOrEqualTo(self)
      make.right.lessThanOrEqualTo(self)
    }
  }
  
  private func setupConfiguration() {
    let nameLabel = UILabel()
    nameLabel.attributedText = configuration.name.withTextStyle(.body1, color: .Text.secondary, alignment: .center)
    nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    
    stackView.addArrangedSubview(nameLabel)
    
    if configuration.isVerified {
      let verificationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = .TKUIKit.Icons.Size16.verification
        imageView.tintColor = .Icon.secondary
        return imageView
      }()
      verificationImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
      stackView.addArrangedSubview(verificationImageView)
    }
  }
}
