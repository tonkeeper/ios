import SwiftUI

public struct CheckboxView: View {
    private let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(.buttonPrimaryBackground)

                SwiftUI.Image.TKUIKit.Icons.Size16.doneBold
                    .renderingMode(.template)
                    .foregroundStyle(.buttonPrimaryForeground)
            } else {
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .strokeBorder(.iconTertiary, lineWidth: Layout.borderWidth)
            }
        }
        .frame(width: Layout.innerSide, height: Layout.innerSide)
        .frame(width: Layout.side, height: Layout.side)
    }

    private enum Layout {
        static let side: CGFloat = 28
        static let innerSide: CGFloat = 22
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 2
    }
}
