import UIKit

enum TKModalCardActionState {
  case none
  case activity
  case result(isSuccess: Bool)
}

struct TKModalCardViewBuilder {
  static func buildContentViews(contentItems: [TKModalCardViewController.Configuration.ContentItem],
                                viewController: UIViewController) -> [UIView] {
    return contentItems.map { contentItem in
      switch contentItem {
      case .item(let item):
        return buildViews(items: [item], viewController: viewController)
      case .list(let items):
        return buildList(items: items)
      }
    }
    .flatMap { $0 }
  }
  
  static func buildList(items: [TKModalCardViewController.Configuration.ListItem]) -> [UIView] {
    let view = TKModalCardListView()
    view.configure(model: items)
    return [view, TKSpacingView(verticalSpacing: .constant(32))]
  }
  
  static func buildViews(items: [TKModalCardViewController.Configuration.Item],
                         viewController: UIViewController,
                         actionStateHandler: ((TKModalCardActionState) -> Void)? = nil) -> [UIView] {
    return items.map { item in
      var views = [UIView]()
      switch item {
      case .text(let textItem, let bottomSpacing):
        let label = UILabel()
        label.numberOfLines = textItem.numberOfLines
        label.attributedText = textItem.text
        views.append(label)
        if bottomSpacing > 0 {
          views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .button(let item, let bottomSpacing):
        let button = buildButton(
          item: item,
          actionStateHandler: actionStateHandler
        )
        views.append(button)
        if bottomSpacing > 0 {
          views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .buttonsRow(let item, let bottomSpacing, let itemsSpacing):
        let buttonsRow = buildButtonsRow(
          item: item,
          itemsSpacing: itemsSpacing,
          actionStateHandler: actionStateHandler
        )
        views.append(buttonsRow)
        if bottomSpacing > 0 {
          views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .customView(let view, let bottomSpacing):
        views.append(view)
        if bottomSpacing > 0 {
          views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      case .customViewController(let itemViewController, let bottomSpacing):
        viewController.addChild(itemViewController)
        views.append(itemViewController.view)
        itemViewController.didMove(toParent: viewController)
        if bottomSpacing > 0 {
          views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
        }
      }
      return views
    }
    .flatMap { $0 }
  }
  
  private static func buildButton(item: TKModalCardViewController.Configuration.Button,
                                  actionStateHandler: ((TKModalCardActionState) -> Void)? = nil) -> UIView {
    let button = TKUIActionButton(
      category: item.category,
      size: item.size
    )
    let asyncButton = TKUIAsyncButton(content: button)
    asyncButton.configure(
      model: TKUIButtonTitleIconContentView.Model(
        title: item.title
      )
    )
    
    button.isEnabled = item.isEnabled
    if item.isActivity {}
    
    button.addTapAction {
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
    }
    return button
  }
  
  private static func buildButtonsRow(item: TKModalCardViewController.Configuration.ButtonsRow,
                                      itemsSpacing: CGFloat,
                                      actionStateHandler: ((TKModalCardActionState) -> Void)? = nil) -> UIView {
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
