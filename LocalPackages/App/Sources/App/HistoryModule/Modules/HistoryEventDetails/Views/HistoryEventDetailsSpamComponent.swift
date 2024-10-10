import UIKit
import TKUIKit

struct HistoryEventDetailsSpamComponent: TKPopUp.Item {
  func getView() -> UIView {
    let view = HistoryEventDetailsSpamView(
      configuration: configuration
    )
    return view
  }
  
  private let configuration: HistoryEventDetailsSpamView.Configuration
  public let bottomSpace: CGFloat
  
  init(configuration: HistoryEventDetailsSpamView.Configuration,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class HistoryEventDetailsSpamView: UIView {
  
  struct Configuration {
    let title: NSAttributedString
  }
  
  private let containerView: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.orange
    view.layer.masksToBounds = true
    view.layer.cornerRadius = 8
    return view
  }()
  private let label = UILabel()

  
  private let configuration: Configuration

  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    containerView.addSubview(label)
    addSubview(containerView)

    label.snp.makeConstraints { make in
      make.top.bottom.equalToSuperview().inset(4)
      make.left.right.equalToSuperview().inset(8)
    }
    containerView.snp.makeConstraints {
      $0.top.bottom.equalToSuperview()
      $0.centerX.equalToSuperview()
    }
    
    label.attributedText = configuration.title
  }
}
