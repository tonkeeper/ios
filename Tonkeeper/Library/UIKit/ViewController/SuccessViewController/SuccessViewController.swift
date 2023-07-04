//
//  SuccessViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import UIKit
import Lottie

final class SuccessViewController: UIViewController {
  
  struct Configuration {
    let title: NSAttributedString
  }
  
  var didFinishAnimation: (() -> Void)?
  
  private let configuration: Configuration
  
  private let contentView = UIView()
  private let tickView: LottieAnimationView = {
    let view = LottieAnimationView(name: .tickAnimationName)
    view.backgroundBehavior = .pauseAndRestore
    view.contentMode = .scaleAspectFit
    return view
  }()
  private let confettiView: LottieAnimationView = {
    let view = LottieAnimationView(name: .confettiAnimationName)
    view.backgroundBehavior = .pauseAndRestore
    view.contentMode = .scaleAspectFill
    return view
  }()
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  // MARK: - Init
    
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    tickView.play { [weak self] _ in
      self?.didFinishAnimation?()
    }
    confettiView.play()
    
    TapticGenerator.generateSuccessFeedback()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
}

// MARK: - Private

private extension SuccessViewController {
  func setup() {
    view.backgroundColor = .Background.page
    
    titleLabel.attributedText = configuration.title
    
    view.addSubview(contentView)
    view.addSubview(confettiView)
    contentView.addSubview(tickView)
    contentView.addSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    confettiView.translatesAutoresizingMaskIntoConstraints = false
    tickView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
      contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      tickView.topAnchor.constraint(equalTo: contentView.topAnchor),
      tickView.widthAnchor.constraint(equalToConstant: .tickSide),
      tickView.heightAnchor.constraint(equalToConstant: .tickSide),
      tickView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      
      titleLabel.topAnchor.constraint(equalTo: tickView.bottomAnchor, constant: .titleTopSpace),
      titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      
      confettiView.topAnchor.constraint(equalTo: view.topAnchor),
      confettiView.leftAnchor.constraint(equalTo: view.leftAnchor),
      confettiView.rightAnchor.constraint(equalTo: view.rightAnchor),
      confettiView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let tickSide: CGFloat = 104
  static let titleTopSpace: CGFloat = 16
}

private extension String {
  static let tickAnimationName = "check480"
  static let confettiAnimationName = "confetti"
}
