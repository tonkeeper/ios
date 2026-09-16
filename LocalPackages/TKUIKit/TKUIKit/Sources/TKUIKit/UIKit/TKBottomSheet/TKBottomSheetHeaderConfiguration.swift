import SnapKit
import SwiftUI
import UIKit

public struct TKBottomSheetHeaderConfiguration {
    public enum IconPosition {
        case left
        case right
    }

    public enum ButtonContent {
        case icon(UIImage)
        case titleIcon(
            title: String? = nil,
            icon: UIImage? = nil,
            iconPosition: IconPosition = .left
        )
    }

    public struct Button {
        public enum Preset {
            case close
        }

        enum Kind {
            case custom(ButtonContent)
            case preset(Preset)
        }

        let kind: Kind
        /// The button renders in SwiftUI, so the value passed back is a zero-sized anchor view that
        /// tracks its frame — use it to position a popup, not to reconfigure the button.
        public var action: ((_ sourceView: UIView?) -> Void)?
        public var isEnabled: Bool
        public var accessibilityIdentifier: String?

        public init(
            content: ButtonContent,
            action: @escaping ((_ sourceView: UIView?) -> Void),
            isEnabled: Bool = true,
            accessibilityIdentifier: String? = nil
        ) {
            kind = .custom(content)
            self.action = action
            self.isEnabled = isEnabled
            self.accessibilityIdentifier = accessibilityIdentifier
        }

        private init(
            preset: Preset,
            action: ((_ sourceView: UIView?) -> Void)?,
            isEnabled: Bool,
            accessibilityIdentifier: String?
        ) {
            kind = .preset(preset)
            self.action = action
            self.isEnabled = isEnabled
            self.accessibilityIdentifier = accessibilityIdentifier
        }

        public static func close(
            action: ((_ sourceView: UIView?) -> Void)? = nil,
            isEnabled: Bool = true,
            accessibilityIdentifier: String? = nil
        ) -> Self {
            Self(
                preset: .close,
                action: action,
                isEnabled: isEnabled,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
    }

    public enum Title {
        public enum ContentLayout {
            case fitContent
            case fillWidth
        }

        public struct TextConfiguration {
            /// Built where rendered so span colors resolve against the live theme.
            public let text: (TKPalette) -> Text
            public let textStyle: TKTextStyle
            public let foregroundColor: TKColor?
            public let lineLimit: Int?
            public let truncationMode: Text.TruncationMode

            public init(
                text: @escaping (TKPalette) -> Text,
                textStyle: TKTextStyle,
                foregroundColor: TKColor? = nil,
                lineLimit: Int? = 1,
                truncationMode: Text.TruncationMode = .tail
            ) {
                self.text = text
                self.textStyle = textStyle
                self.foregroundColor = foregroundColor
                self.lineLimit = lineLimit
                self.truncationMode = truncationMode
            }

            public init(
                _ string: String,
                textStyle: TKTextStyle,
                foregroundColor: TKColor? = nil,
                lineLimit: Int? = 1,
                truncationMode: Text.TruncationMode = .tail
            ) {
                self.init(
                    text: { _ in Text(string) },
                    textStyle: textStyle,
                    foregroundColor: foregroundColor,
                    lineLimit: lineLimit,
                    truncationMode: truncationMode
                )
            }
        }

        case empty
        case title(
            title: String,
            subtitle: String? = nil,
            alignment: ModalCardHeaderContentAlignment = .center
        )
        case text(
            title: TextConfiguration,
            subtitle: TextConfiguration? = nil,
            alignment: ModalCardHeaderContentAlignment = .center
        )
        case customView(
            AnyView,
            alignment: ModalCardHeaderContentAlignment = .center,
            layout: ContentLayout = .fillWidth
        )

        public static func view<Content: View>(
            alignment: ModalCardHeaderContentAlignment = .center,
            layout: ContentLayout = .fillWidth,
            @ViewBuilder _ content: () -> Content
        ) -> Self {
            .customView(
                AnyView(content()),
                alignment: alignment,
                layout: layout
            )
        }

        public static func view(
            _ embeddedView: UIView,
            alignment: ModalCardHeaderContentAlignment = .center,
            layout: ContentLayout = .fillWidth
        ) -> Self {
            .view(
                alignment: alignment,
                layout: layout
            ) {
                TKBottomSheetUIKitTitleViewRepresentable(embeddedView: embeddedView)
            }
        }
    }

    /// Close-only header for sheets whose content carries its own title, so it sits tight above it.
    public static var compact: TKBottomSheetHeaderConfiguration {
        TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(
                top: 8,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
    }

    let title: Title
    public let leftButton: Button?
    public let rightButton: Button?
    let buttonsAlignment: VerticalAlignment
    let contentInsets: UIEdgeInsets

    public init(
        title: Title,
        leftButton: Button? = nil,
        rightButton: Button? = .close(),
        buttonsAlignment: VerticalAlignment = .top,
        contentInsets: UIEdgeInsets? = nil
    ) {
        let resolvedContentInsets: UIEdgeInsets
        if let contentInsets {
            resolvedContentInsets = contentInsets
        } else {
            let defaultContentInsets = UIEdgeInsets(
                top: 16,
                left: 16,
                bottom: 16,
                right: 16
            )
            let multilineContentInsets = UIEdgeInsets(
                top: 8,
                left: 16,
                bottom: 8,
                right: 16
            )
            switch title {
            case .empty, .customView:
                resolvedContentInsets = defaultContentInsets
            case let .title(_, subtitle, _):
                resolvedContentInsets = subtitle == nil
                    ? defaultContentInsets
                    : multilineContentInsets
            case let .text(_, subtitle, _):
                resolvedContentInsets = subtitle == nil
                    ? defaultContentInsets
                    : multilineContentInsets
            }
        }

        self.title = title
        self.leftButton = leftButton
        self.rightButton = rightButton
        self.contentInsets = resolvedContentInsets
        self.buttonsAlignment = buttonsAlignment
    }
}

struct TKBottomSheetHeaderContentView: View {
    @Environment(\.tkPalette) private var palette

    let configuration: TKBottomSheetHeaderConfiguration
    let closeAction: () -> Void

    var body: some View {
        ModalCardHeader(
            config: ModalCardHeader.Config(
                headerContentAlignment: configuration.title.alignment,
                accessoriesAlignment: configuration.buttonsAlignment
            )
        ) {
            buttonView(configuration.leftButton)
        } center: {
            titleView(configuration.title)
        } trailing: {
            buttonView(configuration.rightButton)
        }
        .padding(configuration.contentInsets.edgeInsets)
        .background(.backgroundPage)
    }
}

private extension TKBottomSheetHeaderContentView {
    @ViewBuilder
    func buttonView(_ button: TKBottomSheetHeaderConfiguration.Button?) -> some View {
        if let button {
            TKBottomSheetHeaderButton(
                button: button,
                closeAction: closeAction
            )
            .fixedSize(horizontal: true, vertical: true)
            .layoutPriority(1)
        }
    }

    @ViewBuilder
    func titleView(_ title: TKBottomSheetHeaderConfiguration.Title) -> some View {
        switch title {
        case .empty:
            EmptyView()
        case let .title(title, subtitle, alignment):
            textStack(
                title: .init(
                    title,
                    textStyle: .h3,
                    foregroundColor: .textPrimary
                ),
                subtitle: subtitle.map {
                    .init(
                        $0,
                        textStyle: .body2,
                        foregroundColor: .textSecondary,
                        lineLimit: nil
                    )
                },
                alignment: alignment
            )
        case let .text(title, subtitle, alignment):
            textStack(
                title: title,
                subtitle: subtitle,
                alignment: alignment
            )
        case let .customView(view, alignment, layout):
            customView(
                view,
                alignment: alignment,
                layout: layout
            )
        }
    }

    @ViewBuilder
    func customView(
        _ view: AnyView,
        alignment: ModalCardHeaderContentAlignment,
        layout: TKBottomSheetHeaderConfiguration.Title.ContentLayout
    ) -> some View {
        switch layout {
        case .fitContent:
            view
                .fixedSize(horizontal: true, vertical: false)
                .frame(
                    minHeight: 32,
                    alignment: alignment.swiftUiAlignment
                )
        case .fillWidth:
            view
                .frame(
                    maxWidth: .infinity,
                    minHeight: 32,
                    alignment: alignment.swiftUiAlignment
                )
        }
    }

    func textStack(
        title: TKBottomSheetHeaderConfiguration.Title.TextConfiguration,
        subtitle: TKBottomSheetHeaderConfiguration.Title.TextConfiguration?,
        alignment: ModalCardHeaderContentAlignment
    ) -> some View {
        VStack(alignment: alignment.horizontalAlignment, spacing: 0) {
            configuredText(title, alignment: alignment)
            if let subtitle {
                configuredText(subtitle, alignment: alignment)
                    .padding(.top, 3)
                    .padding(.bottom, 1)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 32,
            alignment: alignment.swiftUiAlignment
        )
    }

    @ViewBuilder
    func configuredText(
        _ configuration: TKBottomSheetHeaderConfiguration.Title.TextConfiguration,
        alignment: ModalCardHeaderContentAlignment
    ) -> some View {
        let text = configuration.text(palette)
            .textStyle(configuration.textStyle)
            .lineLimit(configuration.lineLimit)
            .truncationMode(configuration.truncationMode)
            .multilineTextAlignment(alignment.textAlignment)

        if let foregroundColor = configuration.foregroundColor {
            text.foregroundStyle(foregroundColor)
        } else {
            text
        }
    }
}

private struct TKBottomSheetHeaderButton: View {
    let button: TKBottomSheetHeaderConfiguration.Button
    let closeAction: () -> Void

    @State private var anchorView: UIView?

    var body: some View {
        SwiftUI.Button(action: performAction) {
            content
                .frame(height: Layout.height)
                .background(
                    TKColor.buttonSecondaryBackground
                        .opacity(contentOpacity)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .disabled(!button.isEnabled)
        .accessibilityIdentifier(button.accessibilityIdentifier)
        .overlay(
            AnchorViewResolver { view in
                guard anchorView !== view else { return }
                anchorView = view
            }
        )
    }
}

private extension TKBottomSheetHeaderButton {
    @ViewBuilder
    var content: some View {
        switch button.kind {
        case let .custom(.icon(image)):
            iconView(image)
                .padding(.horizontal, Layout.iconHorizontalPadding)
        case let .custom(.titleIcon(title, icon, iconPosition)):
            // Spacing only when both sit in the stack: an absent one resolves to an empty view, which
            // a plain stack spacing would still pad around.
            HStack(spacing: title != nil && icon != nil ? Layout.titleIconSpacing : 0) {
                switch iconPosition {
                case .left:
                    iconView(icon)
                    titleView(title)
                case .right:
                    titleView(title)
                    iconView(icon)
                }
            }
            .padding(.horizontal, Layout.titleHorizontalPadding)
        case .preset(.close):
            iconView(.TKUIKit.Icons.Size16.close)
                .padding(.horizontal, Layout.iconHorizontalPadding)
        }
    }

    /// Rendered at the image's own size, matching the `contentMode = .center` of the UIKit header
    /// buttons this replaced — the content insets, not the image, set the button's size.
    @ViewBuilder
    func iconView(_ image: UIImage?) -> some View {
        if let image {
            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .foregroundStyle(.buttonSecondaryForeground)
                .opacity(contentOpacity)
        }
    }

    @ViewBuilder
    func titleView(_ title: String?) -> some View {
        if let title {
            Text(title)
                .textStyle(.label2)
                .foregroundStyle(.buttonSecondaryForeground)
                .opacity(contentOpacity)
        }
    }

    var contentOpacity: CGFloat {
        button.isEnabled ? 1 : Layout.disabledOpacity
    }

    func performAction() {
        guard let action = button.action else {
            if case .preset(.close) = button.kind {
                closeAction()
            }
            return
        }
        action(anchorView)
    }

    enum Layout {
        static let height: CGFloat = 32
        static let iconHorizontalPadding: CGFloat = 8
        static let titleHorizontalPadding: CGFloat = 12
        static let titleIconSpacing: CGFloat = 8
        static let disabledOpacity: CGFloat = 0.48
    }
}

private struct TKBottomSheetUIKitTitleViewRepresentable: UIViewRepresentable {
    let embeddedView: UIView

    func makeUIView(context: Context) -> TKBottomSheetUIKitTitleContainerView {
        let containerView = TKBottomSheetUIKitTitleContainerView()
        containerView.update(embeddedView: embeddedView)
        return containerView
    }

    func updateUIView(_ uiView: TKBottomSheetUIKitTitleContainerView, context: Context) {
        uiView.update(embeddedView: embeddedView)
    }
}

private final class TKBottomSheetUIKitTitleContainerView: UIView {
    private var embeddedView: UIView?

    func update(embeddedView: UIView) {
        if self.embeddedView !== embeddedView {
            self.embeddedView?.removeFromSuperview()
            self.embeddedView = embeddedView

            embeddedView.removeFromSuperview()
            addSubview(embeddedView)
            embeddedView.setContentHuggingPriority(.required, for: .horizontal)
            embeddedView.setContentHuggingPriority(.required, for: .vertical)
            embeddedView.setContentCompressionResistancePriority(.required, for: .horizontal)
            embeddedView.setContentCompressionResistancePriority(.required, for: .vertical)
            embeddedView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        embeddedView.setNeedsLayout()
        embeddedView.layoutIfNeeded()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        fittingSize
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        fittingSize
    }
}

private extension TKBottomSheetUIKitTitleContainerView {
    var fittingSize: CGSize {
        guard let embeddedView else {
            return .zero
        }

        embeddedView.setNeedsLayout()
        embeddedView.layoutIfNeeded()

        let size = embeddedView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )

        return CGSize(
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }
}

private extension TKBottomSheetHeaderConfiguration.Title {
    var alignment: ModalCardHeaderContentAlignment {
        switch self {
        case .empty:
            return .center
        case let .title(_, _, alignment):
            return alignment
        case let .text(_, _, alignment):
            return alignment
        case let .customView(_, alignment, _):
            return alignment
        }
    }
}

private extension ModalCardHeaderContentAlignment {
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private extension UIEdgeInsets {
    var edgeInsets: EdgeInsets {
        EdgeInsets(
            top: top,
            leading: left,
            bottom: bottom,
            trailing: right
        )
    }
}
