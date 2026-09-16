import SwiftUI

public enum ModalCardHeaderContentAlignment {
    case leading
    case center
    case trailing

    var swiftUiAlignment: Alignment {
        switch self {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }
}

public struct ModalCardHeader<Leading: View, Center: View, Trailing: View>: View {
    private let config: Config
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    @State private var measuredWidths: [MeasuredElement: CGFloat] = [:]

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
        ZStack(alignment: .topLeading) {
            center
                .frame(
                    minWidth: 0,
                    idealWidth: nil,
                    maxWidth: centerLayoutWidth,
                    minHeight: nil,
                    idealHeight: nil,
                    maxHeight: nil,
                    alignment: centerFrameAlignment
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: centerLayoutMinX)
                .clipped()

            HStack(alignment: config.accessoriesAlignment, spacing: 0) {
                leading
                    .measureWidth(.leading)
                    .layoutPriority(1)

                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)

                trailing
                    .measureWidth(.trailing)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .measureWidth(.container)
        .onPreferenceChange(ModalCardHeaderWidthPreferenceKey.self) { newValue in
            guard measuredWidths != newValue else { return }
            measuredWidths = newValue
        }
    }
}

public extension ModalCardHeader {
    struct Config {
        public var headerContentAlignment: ModalCardHeaderContentAlignment
        public var accessoriesAlignment: VerticalAlignment

        public init(
            headerContentAlignment: ModalCardHeaderContentAlignment = .center,
            accessoriesAlignment: VerticalAlignment = .top
        ) {
            self.headerContentAlignment = headerContentAlignment
            self.accessoriesAlignment = accessoriesAlignment
        }
    }

    init(
        config: Config = Config(),
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            config: config,
            leading: leading(),
            center: center(),
            trailing: trailing()
        )
    }
}

private extension ModalCardHeader {
    var containerWidth: CGFloat {
        measuredWidths[.container, default: 0]
    }

    var leadingWidth: CGFloat {
        measuredWidths[.leading, default: 0]
    }

    var trailingWidth: CGFloat {
        measuredWidths[.trailing, default: 0]
    }

    var centerLayoutWidth: CGFloat? {
        guard containerWidth > 0 else {
            return nil
        }

        switch config.headerContentAlignment {
        case .center:
            let reservedSideWidth = max(leadingWidth, trailingWidth)
            return max(0, containerWidth - reservedSideWidth * 2)
        case .leading, .trailing:
            return max(0, containerWidth - leadingWidth - trailingWidth)
        }
    }

    var centerLayoutMinX: CGFloat {
        switch config.headerContentAlignment {
        case .center:
            return max(leadingWidth, trailingWidth)
        case .leading, .trailing:
            return leadingWidth
        }
    }

    var centerFrameAlignment: Alignment {
        switch config.headerContentAlignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private enum MeasuredElement: Hashable {
    case container
    case leading
    case trailing
}

private struct ModalCardHeaderWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [MeasuredElement: CGFloat] = [:]

    static func reduce(
        value: inout [MeasuredElement: CGFloat],
        nextValue: () -> [MeasuredElement: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func measureWidth(_ element: MeasuredElement) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ModalCardHeaderWidthPreferenceKey.self,
                    value: [element: proxy.size.width]
                )
            }
        )
    }
}
