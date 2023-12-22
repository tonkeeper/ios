//
//  TonDetailsAboutView.swift
//  Tonkeeper
//
//  Created by Grigory on 17.8.23..
//

import UIKit

protocol TonDetailsAboutViewDelegate: AnyObject {
  func didTapTonButton()
  func didTapTwitterButton()
  func didTapChatButton()
  func didTapCommunityButton()
  func didTapWhitepaperButton()
  func didTapTonViewerButton()
  func didTapSourceCodeButton()
}

final class TonDetailsAboutView: UIView {
  
  weak var delegate: TonDetailsAboutViewDelegate?
  
  let headerView = ListTitleView()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8
    return stackView
  }()
  
  private let topStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .leading
    return stackView
  }()
  
  private let middleStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .leading
    return stackView
  }()
  
  private let bottomStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    stackView.alignment = .leading
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TonDetailsAboutView {
  func setup() {
    addSubview(headerView)
    addSubview(stackView)
    stackView.addArrangedSubview(topStackView)
    stackView.addArrangedSubview(middleStackView)
    stackView.addArrangedSubview(bottomStackView)
    
    headerView.configure(model: .init(title: "About"))
    
    let tonOrgButton = TKButton(configuration: .secondarySmall)
    tonOrgButton.configure(model: .init(title: .string("ton.org"), icon: .Icons.Buttons.TonDetailsLinks.tonOrg))
    tonOrgButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapTonButton()
    }), for: .touchUpInside)
    
    let twitterButton = TKButton(configuration: .secondarySmall)
    twitterButton.configure(model: .init(title: .string("Twitter"), icon: .Icons.Buttons.TonDetailsLinks.twitter))
    twitterButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapTwitterButton()
    }), for: .touchUpInside)
    
    let chatButton = TKButton(configuration: .secondarySmall)
    chatButton.configure(model: .init(title: .string("Chat"), icon: .Icons.Buttons.TonDetailsLinks.chat))
    chatButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapChatButton()
    }), for: .touchUpInside)
    
    let communityButton = TKButton(configuration: .secondarySmall)
    communityButton.configure(model: .init(title: .string("Community"), icon: .Icons.Buttons.TonDetailsLinks.community))
    communityButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapCommunityButton()
    }), for: .touchUpInside)
    
    let whitepaperButton = TKButton(configuration: .secondarySmall)
    whitepaperButton.configure(model: .init(title: .string("Whitepaper"), icon: .Icons.Buttons.TonDetailsLinks.whitepaper))
    whitepaperButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapWhitepaperButton()
    }), for: .touchUpInside)
    
    let tonViewerButton = TKButton(configuration: .secondarySmall)
    tonViewerButton.configure(model: .init(title: .string("tonviewer.com"), icon: .Icons.Buttons.TonDetailsLinks.tonviewer))
    tonViewerButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapTonViewerButton()
    }), for: .touchUpInside)
    
    let sourcecodeButton = TKButton(configuration: .secondarySmall)
    sourcecodeButton.configure(model: .init(title: .string("Source code"), icon: .Icons.Buttons.TonDetailsLinks.sourceCode))
    sourcecodeButton.addAction(.init(handler: { [weak self] in
      self?.delegate?.didTapSourceCodeButton()
    }), for: .touchUpInside)

    topStackView.addArrangedSubview(tonOrgButton)
    topStackView.addArrangedSubview(twitterButton)
    topStackView.addArrangedSubview(chatButton)
    topStackView.addArrangedSubview(UIView())
    
    middleStackView.addArrangedSubview(communityButton)
    middleStackView.addArrangedSubview(whitepaperButton)
    middleStackView.addArrangedSubview(UIView())
    
    bottomStackView.addArrangedSubview(tonViewerButton)
    bottomStackView.addArrangedSubview(sourcecodeButton)
    bottomStackView.addArrangedSubview(UIView())
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    headerView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: topAnchor),
      headerView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      headerView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      
      stackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 14),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      stackView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh)
    ])
  }
}

