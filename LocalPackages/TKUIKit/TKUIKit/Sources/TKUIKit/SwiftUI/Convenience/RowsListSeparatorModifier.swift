import SwiftUI

private struct RowsListSeparatorModifier: ViewModifier {
    var index: Int
    var total: Int
    var leadingInset: CGFloat

    func body(content: Content) -> some View {
        if index + 1 < total {
            content
                .overlay {
                    VStack {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(.separatorCommon)
                            .frame(height: TKUIKit.Constants.separatorWidth)
                            .padding(.leading, leadingInset)
                    }
                    .frame(maxWidth: .infinity)
                }
        } else {
            content
        }
    }
}

public extension View {
    func applySeparatorIfNeeded(
        index: Int,
        total: Int,
        leadingInset: CGFloat = 0
    ) -> some View {
        modifier(
            RowsListSeparatorModifier(
                index: index,
                total: total,
                leadingInset: leadingInset
            )
        )
    }
}
