import SwiftUI

private struct CellsGroupSingleCellConfigKey: EnvironmentKey {
    static let defaultValue: CellsGroupModifier.Config? = nil
}

extension EnvironmentValues {
    var cellsGroupSingleCellConfig: CellsGroupModifier.Config? {
        get { self[CellsGroupSingleCellConfigKey.self] }
        set { self[CellsGroupSingleCellConfigKey.self] = newValue }
    }
}

struct CellsGroupCells: Equatable {
    var total: Int = 0
    var tappable: Int = 0
}

struct CellsGroupCellsPreferenceKey: PreferenceKey {
    static let defaultValue = CellsGroupCells()

    static func reduce(value: inout CellsGroupCells, nextValue: () -> CellsGroupCells) {
        let nextValue = nextValue()
        value.total += nextValue.total
        value.tappable += nextValue.tappable
    }
}

public struct CellsGroupModifier: ViewModifier {
    private let config: Config
    @State private var cells = CellsGroupCells()

    public init(config: Config) {
        self.config = config
    }

    public func body(content: Content) -> some View {
        Group {
            if cells.total == 1, cells.tappable == 1 {
                content
                    .environment(\.cellsGroupSingleCellConfig, config)
            } else {
                groupContent(content)
                    .padding(.horizontal, config.horizontalPadding)
            }
        }
        .onPreferenceChange(CellsGroupCellsPreferenceKey.self) { cells = $0 }
    }

    private func groupContent(_ content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .fill(config.backgroundColor)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
            )
    }
}

public extension CellsGroupModifier {
    struct Config {
        public var horizontalPadding: CGFloat
        public var cornerRadius: CGFloat
        public var backgroundColor: TKColor

        public init(
            horizontalPadding: CGFloat = 16,
            cornerRadius: CGFloat = 16,
            backgroundColor: TKColor = .backgroundContent
        ) {
            self.horizontalPadding = horizontalPadding
            self.cornerRadius = cornerRadius
            self.backgroundColor = backgroundColor
        }
    }
}

public extension View {
    func asCellsGroup(config: CellsGroupModifier.Config = .init()) -> some View {
        modifier(CellsGroupModifier(config: config))
    }
}
