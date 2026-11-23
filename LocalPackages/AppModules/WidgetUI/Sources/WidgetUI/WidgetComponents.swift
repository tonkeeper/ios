import SwiftUI
import TKLocalize
import TKUIKit
import WidgetKit

/// Deep Blue on any wallpaper, like the Live Activity.
public enum WidgetTheme {
    public static let resolved = TKResolvedTheme.deepBlue
    static let hiddenAmount = "* * *"
}

@available(iOS 17.0, *)
public extension View {
    /// The system drops the background on the Lock Screen.
    func keeperWidgetBackground() -> some View {
        environment(\.tkResolvedTheme, WidgetTheme.resolved)
            .containerBackground(for: .widget) {
                TKColor.backgroundContent.resolve(WidgetTheme.resolved.palette)
            }
    }
}

public struct WidgetChange: Equatable {
    public let text: String
    public let isDown: Bool

    public init(text: String, isDown: Bool) {
        self.text = text
        self.isDown = isDown
    }
}

public struct WidgetWallet {
    public let name: String
    public let emoji: String?
    public let icon: Image?

    public init(name: String, emoji: String?, icon: Image?) {
        self.name = name
        self.emoji = emoji
        self.icon = icon
    }
}

@available(iOS 17.0, *)
struct WidgetLogoView: View {
    var body: some View {
        Image.TKUIKit.Icons.Size20.tonkeeperSmall
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.accentBlue)
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }
}

@available(iOS 17.0, *)
struct WidgetWalletView: View {
    let wallet: WidgetWallet

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if let emoji = wallet.emoji {
                    Text(emoji).font(.system(size: 16))
                } else if let icon = wallet.icon {
                    icon.resizable().renderingMode(.template).foregroundStyle(.iconSecondary)
                }
            }
            .frame(width: 20, height: 20)
            Text(wallet.name)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }
}

/// The fraction in a smaller font, like the wallet screen's balance: `$8 245` and `.60`.
@available(iOS 17.0, *)
struct WidgetAmountText: View {
    let text: String
    let decimalSeparator: String
    let style: TKTextStyle
    let fractionStyle: TKTextStyle

    var body: some View {
        Text(attributed)
            .textStyle(style)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .privacySensitive()
    }

    private var attributed: AttributedString {
        let (whole, fraction) = Self.split(text, decimalSeparator: decimalSeparator)
        var result = AttributedString(whole)
        result.font = Font(style.font)
        var fractionPart = AttributedString(fraction)
        fractionPart.font = Font(fractionStyle.font)
        result.append(fractionPart)
        return result
    }

    static func split(_ text: String, decimalSeparator: String) -> (whole: Substring, fraction: Substring) {
        guard !decimalSeparator.isEmpty,
              let separator = text.range(of: decimalSeparator, options: .backwards),
              text[separator.upperBound...].first?.isNumber == true
        else { return (text[...], "") }
        return (text[..<separator.lowerBound], text[separator.lowerBound...])
    }
}

/// `−1.79% · 24h`.
@available(iOS 17.0, *)
struct WidgetChangeText: View {
    @Environment(\.tkPalette) private var palette
    let change: WidgetChange
    let period: String?
    let style: TKTextStyle

    var body: some View {
        Text(attributed)
            .textStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var attributed: AttributedString {
        var result = AttributedString(change.text)
        result.foregroundColor = (change.isDown ? TKColor.accentRed : .accentGreen).resolve(palette)
        if let period {
            var suffix = AttributedString(" · \(period)")
            suffix.foregroundColor = TKColor.textSecondary.resolve(palette)
            result.append(suffix)
        }
        return result
    }
}

@available(iOS 17.0, *)
struct WidgetUpdatedText: View {
    let date: Date

    /// Data from an earlier day carries its date, so it does not pass for today's.
    var body: some View {
        let time = Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        Text(TKLocales.ConnectionStatus.updatedAt(time))
            .textStyle(.body3)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
    }
}

/// The token's icon, or its first letter while the icon cannot be loaded.
@available(iOS 17.0, *)
struct WidgetTokenIcon: View {
    let symbol: String
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(symbol.prefix(1))
                    .font(.system(size: size / 2, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.backgroundContentTint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// A price line, green while the price rose over the period and red while it fell; `isDown` takes the direction
/// from a change shown next to it, which can come from another source, and `tint` overrides the colour.
@available(iOS 17.0, *)
struct WidgetChartView: View {
    @Environment(\.tkPalette) private var palette
    let values: [Double]
    let lineWidth: CGFloat
    var fills = false
    var tint: Color?
    var isDown: Bool?

    var body: some View {
        let isDown = isDown ?? ((values.last ?? 0) < (values.first ?? 0))
        let color = tint ?? (isDown ? TKColor.accentRed : .accentGreen).resolve(palette)
        ZStack {
            if fills {
                WidgetChartShape(values: values, inset: lineWidth / 2, closed: true)
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            WidgetChartShape(values: values, inset: lineWidth / 2, closed: false)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Insets the line by half its width, so its peaks are not clipped by the frame.
struct WidgetChartShape: Shape {
    let values: [Double]
    let inset: CGFloat
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        guard values.count > 1, let low = values.min(), let high = values.max() else { return Path() }
        let plot = rect.insetBy(dx: 0, dy: inset)
        let step = plot.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: plot.minX + step * CGFloat(index),
                y: high > low ? plot.maxY - plot.height * CGFloat((value - low) / (high - low)) : plot.midY
            )
        }
        var path = Path()
        path.addLines(points)
        if closed {
            path.addLine(to: CGPoint(x: plot.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: plot.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Before the app has written its data, or without a wallet.
@available(iOS 17.0, *)
public struct WidgetMessageView: View {
    let text: String
    let family: WidgetFamily

    public init(text: String, family: WidgetFamily) {
        self.text = text
        self.family = family
    }

    public var body: some View {
        switch family {
        case .accessoryInline:
            Text(text)
        case .accessoryRectangular, .accessoryCircular:
            let isCircular = family == .accessoryCircular
            Text(text)
                .font(.caption)
                .multilineTextAlignment(isCircular ? .center : .leading)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, isCircular ? 6 : 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isCircular ? .center : .leading)
                .background(AccessoryWidgetBackground())
        default:
            VStack(alignment: .leading, spacing: 8) {
                WidgetLogoView()
                Spacer(minLength: 0)
                Text(text)
                    .textStyle(.label2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
