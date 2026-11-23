import SwiftUI
import UIKit

/// The liquid glass bottom sheet header: a system navigation bar, so the buttons get the system glass,
/// press animation and placement. A title the bar cannot draw as plain text (palette-coloured spans,
/// a custom view, a leading alignment) goes in as a SwiftUI title view.
@available(iOS 26.0, *)
final class TKBottomSheetSystemHeaderView: UIView {
    private let navigationBar = UINavigationBar()
    private let navigationItem = UINavigationItem()
    /// Popups anchor to a view, while a bar button item has none: this one is moved over the tapped item.
    private let anchorView = UIView()
    private var configuration = TKBottomSheetHeaderConfiguration(title: .empty)
    private var closeAction: () -> Void = {}
    /// Kept across updates, as is the title view: sheets such as the Perps ones with a live subtitle
    /// reconfigure the header continuously, and a replaced item drops a press in progress.
    private var leftItem: UIBarButtonItem?
    private var rightItem: UIBarButtonItem?
    private var titleHostingController: TKHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        configuration: TKBottomSheetHeaderConfiguration,
        closeAction: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.closeAction = closeAction
        leftItem = updatedItem(leftItem, for: configuration.leftButton, action: #selector(didTapLeftItem))
        rightItem = updatedItem(rightItem, for: configuration.rightButton, action: #selector(didTapRightItem))
        navigationItem.leftBarButtonItem = leftItem
        navigationItem.rightBarButtonItem = rightItem
        applyTitle(configuration.title)
        setNeedsLayout()
    }

    /// Follows the buttons, not the bar: the bar is taller than its buttons, and the spare room below
    /// them would push the content down. Only a title view taller than the buttons adds height.
    func height(forWidth width: CGFloat) -> CGFloat {
        let titleHeight = navigationItem.titleView?.intrinsicContentSize.height ?? 0
        let rowHeight = max(Layout.buttonSize, titleHeight)
        return ceil(insets.top + rowHeight + insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight = navigationBar.sizeThatFits(
            CGSize(width: max(bounds.width, 1), height: .greatestFiniteMagnitude)
        ).height
        navigationBar.frame = CGRect(x: 0, y: insets.top, width: bounds.width, height: barHeight)
    }
}

@available(iOS 26.0, *)
private extension TKBottomSheetSystemHeaderView {
    enum Layout {
        static let buttonSize: CGFloat = 44
        /// Buttons sit 16 from the sheet's top edge, as in a system sheet.
        static let buttonTop: CGFloat = 16
        static let automaticBottom: CGFloat = 10
        static let compactBottom: CGFloat = 2
    }

    var insets: (top: CGFloat, bottom: CGFloat) {
        switch configuration.insetsKind {
        case .automatic:
            (Layout.buttonTop, Layout.automaticBottom)
        case .compact:
            (Layout.buttonTop, Layout.compactBottom)
        case .custom:
            (Layout.buttonTop, configuration.contentInsets.bottom)
        }
    }

    func setup() {
        backgroundColor = .Background.page
        navigationBar.items = [navigationItem]
        anchorView.isUserInteractionEnabled = false
        anchorView.isAccessibilityElement = false
        addSubview(navigationBar)
        addSubview(anchorView)
        applyAppearance()
    }

    func applyAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .font: TKTextStyle.h3.font,
            .foregroundColor: UIColor.Text.primary,
        ]
        appearance.subtitleTextAttributes = [
            .font: TKTextStyle.body2.font,
            .foregroundColor: UIColor.Text.secondary,
        ]
        appearance.buttonAppearance.normal.titleTextAttributes = [
            .font: TKTextStyle.label2.font,
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = .Icon.primary
    }

    func applyTitle(_ title: TKBottomSheetHeaderConfiguration.Title) {
        switch title {
        case .empty:
            navigationItem.title = nil
            navigationItem.subtitle = nil
            navigationItem.titleView = nil
        case let .title(title, subtitle, .center):
            navigationItem.title = title
            navigationItem.subtitle = subtitle
            navigationItem.titleView = nil
        case .title, .text, .customView:
            navigationItem.title = nil
            navigationItem.subtitle = nil
            navigationItem.titleView = updatedTitleView(title)
        }
    }

    func updatedTitleView(_ title: TKBottomSheetHeaderConfiguration.Title) -> UIView {
        let content = AnyView(TKBottomSheetHeaderTitleView(title: title, minHeight: Layout.buttonSize))
        if let titleHostingController {
            titleHostingController.content = content
            return titleHostingController.view
        }

        let hostingController = TKHostingController(content: content)
        hostingController.sizingOptions = .intrinsicContentSize
        hostingController.safeAreaRegions = []
        hostingController.view.backgroundColor = .clear
        titleHostingController = hostingController
        return hostingController.view
    }

    /// Target-action rather than a primary action, so the item's title and image can change in place.
    func updatedItem(
        _ item: UIBarButtonItem?,
        for button: TKBottomSheetHeaderConfiguration.Button?,
        action: Selector
    ) -> UIBarButtonItem? {
        guard let button else { return nil }

        let item = item ?? UIBarButtonItem(title: nil, style: .plain, target: self, action: action)
        switch button.kind {
        case .preset(.close):
            item.title = nil
            item.image = .TKUIKit.Icons.Size28.xmarkOutline
        case let .custom(.icon(image)):
            item.title = nil
            item.image = image
        case let .custom(.titleIcon(title, icon, _)):
            item.title = title
            item.image = icon
        }
        item.isEnabled = button.isEnabled
        item.accessibilityIdentifier = button.resolvedAccessibilityIdentifier
        return item
    }

    @objc
    func didTapLeftItem(_ item: UIBarButtonItem) {
        configuration.leftButton.map { perform($0, from: item) }
    }

    @objc
    func didTapRightItem(_ item: UIBarButtonItem) {
        configuration.rightButton.map { perform($0, from: item) }
    }

    func perform(_ button: TKBottomSheetHeaderConfiguration.Button, from item: UIBarButtonItem) {
        guard let action = button.action else {
            if case .preset(.close) = button.kind {
                closeAction()
            }
            return
        }
        anchorView.frame = item.frame(in: self) ?? .zero
        action(anchorView)
    }
}
