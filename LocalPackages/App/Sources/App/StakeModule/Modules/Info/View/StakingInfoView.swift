//
//  File.swift
//  
//
//  Created by Semyon on 19/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

struct StakingInfo {
  let title: String
  let value: String
  let badge: String?
}

final class StackingInfoRow: UIView {
  struct Model {
    let info: StakingInfo
  }

  let titleLabel = UILabel()
  let subtitleLabel = UILabel()

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup(with model: Model) {
    addSubview(titleLabel)
    addSubview(subtitleLabel)

    titleLabel.attributedText = model.info.title.withTextStyle(
      .body2,
      color: .Text.secondary
    )
    subtitleLabel.attributedText = model.info.value.withTextStyle(
      .body2,
      color: .Text.primary
    )

    titleLabel.snp.makeConstraints { make in
      make.centerY.equalTo(snp.centerY)
      make.leading.equalTo(snp.leading)
    }
    subtitleLabel.snp.makeConstraints { make in
      make.centerY.equalTo(titleLabel.snp.centerY)
      make.trailing.equalTo(snp.trailing)
    }
    snp.makeConstraints { make in
      make.height.equalTo(36)
    }
    if let badge = model.info.badge {
      let badgeView = BadgeView(model: badge)
      addSubview(badgeView)
      badgeView.snp.makeConstraints { make in
        make.leading.equalTo(titleLabel.snp.trailing).offset(6)
        make.centerY.equalTo(titleLabel.snp.centerY)
      }
      subtitleLabel.snp.makeConstraints { make in
        make.leading.greaterThanOrEqualTo(badgeView.snp.trailing).offset(6)
      }
    } else {
      subtitleLabel.snp.makeConstraints { make in
        make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(6)
      }
    }
  }
}

final class StakingInfoView: UIView {
  struct Model {
    let info: [StakingInfo]
  }

  let stackView = UIStackView()

  init(model: Model) {
    super.init(frame: .zero)
    setup(with: model)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc
  private func handleRowTap(_ row: StackingInfoRow) {
    print("did tap \(row)")
  }

  private func setup(with model: Model) {
    addSubview(stackView)

    stackView.alignment = .fill
    stackView.distribution = .fillEqually
    stackView.spacing = 0
    stackView.axis = .vertical
    stackView.backgroundColor = .Background.content
    stackView.layer.cornerRadius = 16
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

    for info in model.info {
      let row = StackingInfoRow(model: .init(info: info))
      stackView.addArrangedSubview(row)
      row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleRowTap)))
    }
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
