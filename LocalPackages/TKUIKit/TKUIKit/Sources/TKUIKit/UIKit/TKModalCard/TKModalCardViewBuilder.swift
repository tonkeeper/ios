import UIKit

enum TKModalCardActionState {
    case none
    case activity
    case result(isSuccess: Bool)
}

enum TKModalCardViewBuilder {
    static func buildContentViews(
        contentItems: [TKModalCardViewController.Configuration.ContentItem],
        viewController: UIViewController,
        copyToastConfiguration: ToastPresenter.Configuration
    ) -> [UIView] {
        return contentItems.map { contentItem in
            switch contentItem {
            case let .item(item):
                return buildViews(
                    items: [item],
                    viewController: viewController
                )
            case let .list(items):
                return buildList(items: items, copyToastConfiguration: copyToastConfiguration)
            }
        }
        .flatMap { $0 }
    }

    static func buildList(
        items: [TKModalCardViewController.Configuration.ListItem],
        copyToastConfiguration: ToastPresenter.Configuration
    ) -> [UIView] {
        let view = TKModalCardListView()
        view.copyToastConfiguration = copyToastConfiguration
        view.configure(model: items)
        return [view, TKSpacingView(verticalSpacing: .constant(32))]
    }

    static func buildViews(
        items: [TKModalCardViewController.Configuration.Item],
        viewController: UIViewController,
        actionStateHandler: ((TKModalCardActionState) -> Void)? = nil
    ) -> [UIView] {
        return items.map { item in
            var views = [UIView]()
            switch item {
            case let .text(textItem, bottomSpacing):
                let label = UILabel()
                label.numberOfLines = textItem.numberOfLines
                label.attributedText = textItem.text
                views.append(label)
                if bottomSpacing > 0 {
                    views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
                }
            case let .button(item, bottomSpacing):
                let button = buildButton(
                    item: item,
                    actionStateHandler: actionStateHandler
                )
                views.append(button)
                if bottomSpacing > 0 {
                    views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
                }
            case let .buttonsRow(item, bottomSpacing, itemsSpacing):
                let buttonsRow = buildButtonsRow(
                    item: item,
                    itemsSpacing: itemsSpacing,
                    actionStateHandler: actionStateHandler
                )
                views.append(buttonsRow)
                if bottomSpacing > 0 {
                    views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
                }
            case let .customView(view, bottomSpacing):
                views.append(view)
                if bottomSpacing > 0 {
                    views.append(TKSpacingView(verticalSpacing: .constant(bottomSpacing)))
                }
            case let .customViewController(itemViewController, bottomSpacing):
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

    private static func buildButton(
        item: TKModalCardViewController.Configuration.Button,
        actionStateHandler: ((TKModalCardActionState) -> Void)? = nil
    ) -> UIView {
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
                    if isSuccess {
                        item.completionAction?(isSuccess)
                    } else {
                        actionStateHandler?(.none)
                    }
                }
            }

            item.tapAction?(activityClosure, completionClosure)
        }
        return button
    }

    private static func buildButtonsRow(
        item: TKModalCardViewController.Configuration.ButtonsRow,
        itemsSpacing: CGFloat,
        actionStateHandler: ((TKModalCardActionState) -> Void)? = nil
    ) -> UIView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = itemsSpacing
        for element in item.buttons {
            let button = buildButton(
                item: element,
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
