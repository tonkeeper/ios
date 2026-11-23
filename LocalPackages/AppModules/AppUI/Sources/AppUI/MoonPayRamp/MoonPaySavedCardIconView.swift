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

    /// `size` is the card's width; its height follows the design's 44×30 ratio.
    public var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * 0.11)
                .fill(.accentBlue)
            brandMark
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, inset)
                .padding(.leading, inset)
                .padding(.trailing, inset)
            Text(icon.last4)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.constantWhite)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, inset)
                .padding(.bottom, inset * 0.75)
        }
        .frame(width: size, height: size * Self.aspectRatio)
    }

    /// The design's logos for Visa and Mastercard; any other brand is written out.
    @ViewBuilder
    private var brandMark: some View {
        switch Brand(icon.brand) {
        case .visa:
            SwiftUI.Image.TKUIKit.Artwork.PaymentCards.visa
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.constantWhite)
                .frame(width: size * 19 / 44, height: size * 6 / 44)
        case .mastercard:
            SwiftUI.Image.TKUIKit.Artwork.PaymentCards.mastercard
                .resizable()
                .frame(width: size * 10 / 44, height: size * 6 / 44)
        case .other:
            Text(icon.brand.uppercased())
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .italic()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.constantWhite)
        }
    }

    private enum Brand {
        case visa
        case mastercard
        case other

        init(_ name: String) {
            switch name.lowercased().filter(\.isLetter) {
            case "visa": self = .visa
            case "mastercard": self = .mastercard
            default: self = .other
            }
        }
    }

    private var fontSize: CGFloat {
        size * 0.18
    }

    private var inset: CGFloat {
        size * 0.09
    }

    private static let aspectRatio: CGFloat = 30 / 44
}
