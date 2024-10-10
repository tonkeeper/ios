import UIKit
import TKUIKit

struct HistoryEventDetailsSwapHeaderComponent: TKPopUp.Item {
  func getView() -> UIView {
    let view = HistoryEventDetailsSwapHeaderView(
      configuration: configuration
    )
    return view
  }
  
  private let configuration: HistoryEventDetailsSwapHeaderView.Configuration
  public let bottomSpace: CGFloat
  
  init(configuration: HistoryEventDetailsSwapHeaderView.Configuration, 
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class HistoryEventDetailsSwapHeaderView: UIView {
  
  struct Configuration {
    let leftImageModel: TKImageView.Model
    let rightImageModel: TKImageView.Model
  }
  
  private let configuration: Configuration
  
  private let leftImageView = TKImageView()
  private let rightImageView = TKImageView()
  private let containerView = UIView()
  
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    if #unavailable(iOS 17.0) {
      updateColors()
    }
  }
  
  private func setup() {
    leftImageView.layer.masksToBounds = true
    leftImageView.layer.cornerRadius = 38
    leftImageView.layer.borderWidth = 4
    
    rightImageView.layer.masksToBounds = true
    rightImageView.layer.cornerRadius = 38
    rightImageView.layer.borderWidth = 4
    
    updateColors()
    
    addSubviews(containerView)
    containerView.addSubview(leftImageView)
    containerView.addSubview(rightImageView)
    
    setupConstraints()
    setupConfiguration()
    
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
        (self: Self, previousTraitCollection: UITraitCollection) in
        self.updateColors()
      }
    }
  }
  
  private func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.top.centerX.bottom.equalTo(self)
    }
    leftImageView.snp.makeConstraints { make in
      make.width.height.equalTo(76)
      make.left.bottom.top.equalTo(containerView)
    }
    
    rightImageView.snp.makeConstraints { make in
      make.width.height.equalTo(76)
      make.right.top.bottom.equalTo(containerView)
      make.left.equalTo(leftImageView.snp.right).offset(-16)
    }
  }
  
  private func setupConfiguration() {
    leftImageView.configure(model: configuration.leftImageModel)
    rightImageView.configure(model: configuration.rightImageModel)
  }
  
  func updateColors() {
    leftImageView.layer.borderColor = UIColor.Background.page.cgColor
    rightImageView.layer.borderColor = UIColor.Background.page.cgColor
  }
}
