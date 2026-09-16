import SwiftUI

public struct CellCenter<PrimaryRow: View, SecondaryRow: View>: View {
    private let primaryRow: PrimaryRow
    private let secondaryRow: SecondaryRow
    private let contentInsets: EdgeInsets

    public init(
        primaryRow: PrimaryRow,
        secondaryRow: SecondaryRow,
        contentInsets: (inout EdgeInsets) -> Void = { _ in }
    ) {
        self.primaryRow = primaryRow
        self.secondaryRow = secondaryRow
        self.contentInsets = {
            var insets = Layout.insets
            contentInsets(&insets)
            return insets
        }()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            primaryRow
            secondaryRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(contentInsets)
    }
}

private extension CellCenter {
    enum Layout {
        static var insets: EdgeInsets {
            EdgeInsets(
                top: 16,
                leading: 16,
                bottom: 16,
                trailing: 16
            )
        }
    }
}
