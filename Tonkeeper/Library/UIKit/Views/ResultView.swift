//
//  ResultView.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

final class ResultView: UIView {
  
  enum State {
    case success
    case failure
    
    var tintColor: UIColor {
      switch self {
      case .success: return .Accent.green
      case .failure: return .Accent.red
      }
    }
    
    var title: String? {
      switch self {
      case .success: return "Done"
      case .failure: return "Error"
      }
    }
    
    var icon: UIImage? {
      switch self {
      case .success: return .Icons.State.success
      case .failure: return .Icons.State.fail
      }
    }
  }
  
  var state: State {
    didSet { didChangeState() }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let iconImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    return imageView
  }()
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label2)
    label.textAlignment = .center
    return label
  }()
  
  init(state: State) {
    self.state = state
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    stackView.systemLayoutSizeFitting(.zero)
  }
}

private extension ResultView {
  func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(titleLabel)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
    ])
    
    didChangeState()
  }
  
  func didChangeState() {
    iconImageView.tintColor = state.tintColor
    iconImageView.image = state.icon
    
    titleLabel.textColor = state.tintColor
    titleLabel.text = state.title
  }
}

