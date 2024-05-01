import UIKit
import TKUIKit

public final class TKRecoveryPhraseItemView: UIView, ConfigurableView {
  private let indexLabel = UILabel()
  private let wordLabel = UILabel()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .bottom
    stackView.spacing = 4
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let index: Int
    let word: String
    
    public init(index: Int, word: String) {
      self.index = index
      self.word = word
    }
  }
  
  public func configure(model: Model) {
    indexLabel.attributedText = "\(model.index)."
      .withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left
      )
    wordLabel.attributedText = model.word
      .withTextStyle(
        .body1,
        color: .Text.primary,
        alignment: .left
      )
  }
}

private extension TKRecoveryPhraseItemView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(indexLabel)
    stackView.addArrangedSubview(wordLabel)

    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    indexLabel.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),

      indexLabel.widthAnchor.constraint(equalToConstant: 24)
    ])
  }
}
