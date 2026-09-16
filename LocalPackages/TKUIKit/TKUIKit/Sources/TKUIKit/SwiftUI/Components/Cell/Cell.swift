import SwiftUI
import UIKit

public struct Cell<Leading: View, Center: View, Trailing: View>: View {
    @Environment(\.tkPalette) private var palette
    @Environment(\.cellsGroupSingleCellConfig) private var cellsGroupSingleCellConfig

    private let config: Config
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    init(
        config: Config,
        leading: Leading,
        center: Center,
        trailing: Trailing
    ) {
        self.config = config
        self.leading = leading
        self.center = center
        self.trailing = trailing
    }

    public var body: some View {
        tappableContent
            .padding(.horizontal, cellsGroupSingleCellConfig?.horizontalPadding ?? 0)
    }

    @ViewBuilder
    private var tappableContent: some View {
        if let action = config.action {
            Button(action: action) {
                contentBody
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: config.haptic))
        } else {
            contentBody
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let cellsGroupSingleCellConfig {
            cellContent
                .background(
                    RoundedRectangle(
                        cornerRadius: cellsGroupSingleCellConfig.cornerRadius,
                        style: .continuous
                    )
                    .fill(cellsGroupSingleCellConfig.backgroundColor)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cellsGroupSingleCellConfig.cornerRadius,
                        style: .continuous
                    )
                )
        } else {
            cellContent
        }
    }

    private var cellContent: some View {
        HStack(alignment: config.verticalAlignment, spacing: 0) {
            leading

            center
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(config.style.backgroundColor.resolve(palette))
        .overlay { divider }
        .contentShape(Rectangle())
        .preference(
            key: CellsGroupCellsPreferenceKey.self,
            value: .init(
                total: 1,
                tappable: config.action == nil ? 0 : 1
            )
        )
    }

    @ViewBuilder
    private var divider: some View {
        if config.showsDivider {
            VStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(config.style.separatorColor)
                    .frame(height: TKUIKit.Constants.separatorWidth)
                    .padding(.leading, config.style.dividerLeadingInset)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

public extension Cell {
    struct Config {
        public var style: Style
        public var showsDivider: Bool
        public var verticalAlignment: VerticalAlignment
        public var haptic: TKTapAnimationHaptic
        public var action: (() -> Void)?

        public init(
            style: Style = .regular,
            showsDivider: Bool = false,
            verticalAlignment: VerticalAlignment = .center,
            haptic: TKTapAnimationHaptic = .none,
            action: (() -> Void)? = nil
        ) {
            self.style = style
            self.showsDivider = showsDivider
            self.verticalAlignment = verticalAlignment
            self.haptic = haptic
            self.action = action
        }
    }

    struct Style {
        public var dividerLeadingInset: CGFloat
        public var backgroundColor: TKColor
        public var separatorColor: TKColor

        public init(
            dividerLeadingInset: CGFloat,
            backgroundColor: TKColor = .backgroundContent,
            separatorColor: TKColor = .separatorCommon
        ) {
            self.dividerLeadingInset = dividerLeadingInset
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
        }

        public static var regular: Style {
            Style(
                dividerLeadingInset: 16
            )
        }

        public static var grouped: Style {
            Style(
                dividerLeadingInset: 16,
                backgroundColor: .clear
            )
        }
    }
}
