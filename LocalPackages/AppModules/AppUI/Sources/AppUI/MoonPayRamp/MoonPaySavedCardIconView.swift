import SwiftUI
import TKUIKit

public struct MoonPaySavedCardIcon: Equatable {
    public var brand: String
    public var last4: String

    public init(brand: String, last4: String) {
        self.brand = brand
        self.last4 = last4
    }
}

/// A small card with the brand and the last four digits, used where MoonPay has no image for a
/// stored card.
public struct MoonPaySavedCardIconView: View {
    public let icon: MoonPaySavedCardIcon
    public var size: CGFloat

    public init(icon: MoonPaySavedCardIcon, size: CGFloat = 44) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.accentBlue)
            Text(icon.brand.uppercased())
                .font(.system(size: size * 0.2, weight: .heavy, design: .rounded))
                .italic()
                .foregroundStyle(.constantWhite)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
                .padding(.trailing, 5)
            Text(icon.last4)
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundStyle(.constantWhite)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 5)
                .padding(.bottom, 4)
        }
        .frame(width: size * 1.45, height: size)
    }
}
