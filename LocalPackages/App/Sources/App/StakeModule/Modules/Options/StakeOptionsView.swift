//
//  StakeOptionsView.swift
//
//
//  Created by Semyon on 18/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeOptionsView: UIView {
  
  private let modalContentContainer = UIView()
  
  let scrollView = TKUIScrollView()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentVerticalPadding
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .Background.page
    
    addSubview(modalContentContainer)
    
    modalContentContainer.addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    let liquidStakingView = StakingView(model: .init(
      title: "Liquid Staking",
      providers: [
        .init(
          iconURL: iconURL,
          title: "Tonstakers",
          subtitle: "Minimum deposit 1 TON.\nAPY ≈ 5.01%",
          badge: "MAX APY",
          isSelected: true
        ),
        .init(
          iconURL: iconURL,
          title: "Bemo",
          subtitle: "Minimum deposit 1 TON.\nAPY ≈ 4.01%",
          badge: nil,
          isSelected: false
        ),
      ],
      style: .liquid
    ))
    stackView.addArrangedSubview(liquidStakingView)

    let otherStakingView = StakingView(model: .init(
      title: "Other",
      providers: [
        .init(
          iconURL: iconURL,
          title: "Tonstakers",
          subtitle: "Minimum deposit 1 TON.\nAPY ≈ 5.01%",
          badge: "MAX APY",
          isSelected: true
        ),
        .init(
          iconURL: iconURL,
          title: "Bemo",
          subtitle: "Minimum deposit 1 TON.\nAPY ≈ 4.01%",
          badge: nil,
          isSelected: false
        ),
      ],
      style: .other
    ))
    stackView.addArrangedSubview(otherStakingView)
    
    modalContentContainer.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.bottom.right.equalTo(self).priority(.high)
    }
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
