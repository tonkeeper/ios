import UIKit

public final class TKListItemTextAccessoryView: UIView {
  
  public struct Configuration {
    public let textViewConfiguration: TKListItemTextView.Configuration
    
    public static var `default`: Configuration {
      Configuration(
        textViewConfiguration: TKListItemTextView.Configuration(
          text: "Text",
          color: .Accent.blue,
          textStyle: .label1
        )
      )
    }
    
    public init(textViewConfiguration: TKListItemTextView.Configuration) {
      self.textViewConfiguration = textViewConfiguration
    }
  }
  
  public var configuration: Configuration = .default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let textView = TKListItemTextView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let sizeThatFits = textView.sizeThatFits(.zero)
    textView.frame = CGRect(x: 0, y: 0, width: sizeThatFits.width, height: bounds.height)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let sizeThatFits = textView.sizeThatFits(.zero)
    return CGSize(width: sizeThatFits.width + 16, height: sizeThatFits.height)
  }
  
  private func setup() {
//    isUserInteractionEnabled = false
    addSubview(textView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    textView.configuration = configuration.textViewConfiguration
  }
}
