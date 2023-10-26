//
//  ModalCardViewBuilder.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 20.10.2023.
//

import UIKit

enum ModalCardActionState {
  case none
  case activity
  case result(isSuccess: Bool)
}

struct ModalCardViewBuilder {
  static func buildViews(items: [ModalCardViewController.Configuration.Item],
                         viewController: UIViewController,
                         actionStateHandler: ((ModalCardActionState) -> Void)? = nil) -> [UIView] {
    return items.map { item in
      var views = [UIView]()
      switch item {
      case .text(let textItem, let bottomSpacing):
        let label = UILabel()
        label.numberOfLines = textItem.numberOfLines
        label.attributedText = textItem.text
        views.append(label)
        if bottomSpacing > 0 {
          views.append(SpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .button(let item, let bottomSpacing):
        let button = buildButton(
          item: item,
          actionStateHandler: actionStateHandler
        )
        views.append(button)
        if bottomSpacing > 0 {
          views.append(SpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .buttonsRow(let item, let bottomSpacing, let itemsSpacing):
        let buttonsRow = buildButtonsRow(
          item: item,
          itemsSpacing: itemsSpacing,
          actionStateHandler: actionStateHandler
        )
        views.append(buttonsRow)
        if bottomSpacing > 0 {
          views.append(SpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .customView(let view, let bottomSpacing):
        views.append(view)
        if bottomSpacing > 0 {
          views.append(SpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .customViewController(let itemViewController, let bottomSpacing):
        viewController.addChild(itemViewController)
        views.append(itemViewController.view)
        itemViewController.didMove(toParent: viewController)
        if bottomSpacing > 0 {
          views.append(SpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      }
      return views
    }
    .flatMap { $0 }
  }
  
  private static func buildButton(item: ModalCardViewController.Configuration.Button,
                                  actionStateHandler: ((ModalCardActionState) -> Void)? = nil) -> UIView {
    let button = TKButton(configuration: item.configuration)
    let buttonActivityContainer = ActivityViewContainer(view: button)
    button.titleLabel.text = item.title
    button.isEnabled = item.isEnabled
    if item.isActivity {
      buttonActivityContainer.showActivity()
    }
    
    button.addAction(.init(handler: {

      let activityClosure: (Bool) -> Void = { isActivity in
        guard isActivity else { return }
        actionStateHandler?(.activity)
      }

      let completionClosure: (Bool) -> Void = { isSuccess in
        actionStateHandler?(.result(isSuccess: isSuccess))
        DispatchQueue.main.asyncAfter(deadline: .now() + .completionDelay) {
          item.completionAction?(isSuccess)
          actionStateHandler?(.none)
        }
      }

      item.tapAction?(activityClosure, completionClosure)
    }), for: .touchUpInside)
    return button
  }
  
  private static func buildButtonsRow(item: ModalCardViewController.Configuration.ButtonsRow,
                                      itemsSpacing: CGFloat,
                                      actionStateHandler: ((ModalCardActionState) -> Void)? = nil) -> UIView {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = itemsSpacing
    item.buttons.forEach {
      let button = buildButton(
        item: $0,
        actionStateHandler: actionStateHandler
      )
      stackView.addArrangedSubview(button)
    }
    return stackView
  }
}

private extension TimeInterval {
  static let completionDelay: TimeInterval = 1
}
