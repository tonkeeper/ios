import SwiftUI
import UIKit

public struct RadioButtonView: View {
    @Environment(\.tkPalette) private var palette

    public let isSelected: Bool
    private let size: CGFloat
    private let trailingPadding: CGFloat

    public init(
        isSelected: Bool,
        size: CGFloat = 24,
        trailingPadding: CGFloat = 16
    ) {
        self.isSelected = isSelected
        self.size = size
        self.trailingPadding = trailingPadding
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? palette.button.primaryBackground : palette.icon.tertiary,
                    lineWidth: Layout.outerLineWidth(for: size)
                )
                .frame(
                    width: Layout.outerDiameter(for: size),
                    height: Layout.outerDiameter(for: size)
                )

            if isSelected {
                Circle()
                    .fill(.buttonPrimaryBackground)
                    .frame(
                        width: Layout.innerDiameter(for: size),
                        height: Layout.innerDiameter(for: size)
                    )
            }
        }
        .frame(width: size, height: size)
        .padding(.trailing, trailingPadding)
    }
}

private enum Layout {
    static func outerDiameter(for size: CGFloat) -> CGFloat {
        size * 0.8
    }

    static func innerDiameter(for size: CGFloat) -> CGFloat {
        size * 0.4
    }

    static func outerLineWidth(for size: CGFloat) -> CGFloat {
        outerDiameter(for: size) * 0.1
    }
}
