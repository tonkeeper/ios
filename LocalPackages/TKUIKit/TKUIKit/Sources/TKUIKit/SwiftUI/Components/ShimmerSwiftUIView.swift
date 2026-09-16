import SwiftUI
import UIKit

public struct ShimmerSwiftUIView: View {
    public var config: Config

    public init(
        config: Config = Config()
    ) {
        self.config = config
    }

    public var body: some View {
        switch config.cornerRadius {
        case let .value(radius):
            fillColor
                .clipShape(RoundedRectangle(cornerRadius: radius))
        case .capsule:
            fillColor
                .clipShape(Capsule())
        }
    }

    private var fillColor: TKColor {
        config.color
    }
}

public extension ShimmerSwiftUIView {
    enum CornerRadius {
        case value(CGFloat)
        case capsule
    }

    struct Config {
        public var color: TKColor
        public var cornerRadius: CornerRadius

        public init(
            color: TKColor = .backgroundContent,
            cornerRadius: CornerRadius = .value(12)
        ) {
            self.color = color
            self.cornerRadius = cornerRadius
        }
    }
}

#Preview {
    ShimmerSwiftUIView()
        .frame(width: 56, height: 56)
        .debugPreview()
}
