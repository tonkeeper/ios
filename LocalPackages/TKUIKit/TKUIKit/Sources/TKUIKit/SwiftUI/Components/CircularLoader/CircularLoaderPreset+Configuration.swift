import SwiftUI

extension CircularLoaderPreset {
    func configuration(palette: TKPalette) -> CircularLoaderConfiguration {
        switch self {
        case .xSmall, .small, .medium:
            CircularLoaderConfiguration(
                lineWidth: lineWidth,
                progressColor: palette.icon.primary,
                trackColor: palette.icon.primary.opacity(0.32),
                size: size,
                contentPadding: contentPadding
            )
        case let .custom(configuration):
            configuration
        }
    }

    private var lineWidth: CGFloat {
        switch self {
        case .xSmall, .small:
            2
        case .medium:
            3
        case let .custom(configuration):
            configuration.lineWidth
        }
    }

    private var size: CGSize {
        switch self {
        case .xSmall:
            CGSize(width: 12, height: 12)
        case .small:
            CGSize(width: 16, height: 16)
        case .medium:
            CGSize(width: 24, height: 24)
        case let .custom(configuration):
            configuration.size
        }
    }

    private var contentPadding: CGFloat {
        switch self {
        case .xSmall:
            0
        case .small:
            1
        case .medium:
            1 + 1 / UIScreen.main.scale
        case let .custom(configuration):
            configuration.contentPadding
        }
    }
}
