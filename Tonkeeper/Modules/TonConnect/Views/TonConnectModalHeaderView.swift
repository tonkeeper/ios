//
//  TonConnectModalHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit

final class TonConnectModalHeaderView: UIView, ConfigurableView {
  
  // MARK: - Subviews
  
  private let tonImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .red
    return imageView
  }()
  private let appImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .green
    return imageView
  }()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
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
  
  struct Model {
    let tonImage: Image
    let appImage: Image
  }
  
  func configure(model: Model) {
    
  }
}

private extension TonConnectModalHeaderView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(tonImageView)
    stackView.addArrangedSubview(appImageView)
    stackView.setCustomSpacing(86, after: tonImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    tonImageView.translatesAutoresizingMaskIntoConstraints = false
    appImageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      
      tonImageView.widthAnchor.constraint(equalToConstant: 72),
      tonImageView.heightAnchor.constraint(equalToConstant: 72),
      
      appImageView.widthAnchor.constraint(equalToConstant: 72),
      appImageView.heightAnchor.constraint(equalToConstant: 72)
    ])
  }
}
