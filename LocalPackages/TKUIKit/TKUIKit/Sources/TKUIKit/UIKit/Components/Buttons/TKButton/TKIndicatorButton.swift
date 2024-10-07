import UIKit

final public class TKIndicatorButton: TKButton {

  private enum Constants {
    static let indicatorSide: CGFloat = 6
  }

  private let indicatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.red
    view.layer.masksToBounds = true
    return view
  }()

  override public init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    addSubview(indicatorView)
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    indicatorView.frame = CGRect(
      x: buttonContentView.imageView.frame.maxX + configuration.spacing + padding.left,
      y: buttonContentView.imageView.frame.minY + padding.top,
      width: Constants.indicatorSide,
      height: Constants.indicatorSide
    )
    indicatorView.layer.cornerRadius = Constants.indicatorSide / 2
  }

  public func configure(isIndicatorHidden: Bool) {
    indicatorView.isHidden = isIndicatorHidden
  }
}
