import SwiftUI

public enum CircularLoaderMode: Hashable {
    case determinate
    case indeterminate
}

public enum CircularLoaderPreset: Hashable {
    case xSmall
    case small
    case medium
    case custom(CircularLoaderConfiguration)
}

public struct CircularLoaderConfiguration: Hashable {
    var lineWidth: CGFloat
    var progressColor: Color
    var trackColor: Color
    var size: CGSize
    var contentPadding: CGFloat

    public init(
        lineWidth: CGFloat,
        progressColor: Color,
        trackColor: Color,
        size: CGSize,
        contentPadding: CGFloat
    ) {
        self.lineWidth = lineWidth
        self.progressColor = progressColor
        self.trackColor = trackColor
        self.size = size
        self.contentPadding = contentPadding
    }
}

public struct CircularLoader: View {
    @Environment(\.tkPalette) private var palette

    public var mode: CircularLoaderMode
    public var duration: TimeInterval
    public var onComplete: () -> Void
    public var restartToken: Int
    public var preset: CircularLoaderPreset

    @State private var startDate = Date()
    @State private var didComplete = false

    public init(
        mode: CircularLoaderMode = .determinate,
        preset: CircularLoaderPreset,
        duration: TimeInterval = 10,
        onComplete: @escaping () -> Void = {},
        restartToken: Int = 0
    ) {
        self.mode = mode
        self.duration = duration
        self.onComplete = onComplete
        self.restartToken = restartToken
        self.preset = preset
    }

    private var configuration: CircularLoaderConfiguration {
        preset.configuration(palette: palette)
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let progress = progress(at: context.date)
            let isComplete = progress >= 1

            ZStack {
                Circle()
                    .stroke(configuration.trackColor, style: StrokeStyle(lineWidth: configuration.lineWidth))

                switch mode {
                case .determinate:
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(configuration.progressColor, style: progressStrokeStyle)
                        .rotationEffect(.degrees(-90))
                case .indeterminate:
                    Circle()
                        .trim(from: 0, to: Layout.indeterminateArcLength)
                        .stroke(configuration.progressColor, style: progressStrokeStyle)
                        .rotationEffect(indeterminateRotation(at: context.date))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(configuration.contentPadding)
            .frame(width: configuration.size.width, height: configuration.size.height)
            .onAppear {
                completeIfNeeded(isComplete: isComplete)
            }
            .onChange(of: identity) { _ in
                startDate = context.date
                didComplete = false
            }
            .onChange(of: isComplete) { isComplete in
                completeIfNeeded(isComplete: isComplete)
            }
        }
    }
}

private extension CircularLoader {
    struct Identity: Hashable {
        let mode: CircularLoaderMode
        let duration: TimeInterval
        let restartToken: Int
    }

    var identity: Identity {
        Identity(
            mode: mode,
            duration: duration,
            restartToken: restartToken
        )
    }

    var progressStrokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: configuration.lineWidth,
            lineCap: .round
        )
    }

    func progress(at date: Date) -> CGFloat {
        guard mode == .determinate else {
            return 0
        }
        guard duration > 0 else {
            return 1
        }

        let elapsed = date.timeIntervalSince(startDate)
        return min(max(CGFloat(elapsed / duration), 0), 1)
    }

    func indeterminateRotation(at date: Date) -> Angle {
        let progress = date
            .timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Layout.indeterminateRotationDuration)
            / Layout.indeterminateRotationDuration

        return .degrees(progress * 360 - 90)
    }

    func completeIfNeeded(isComplete: Bool) {
        guard mode == .determinate, isComplete, !didComplete else {
            return
        }
        didComplete = true
        onComplete()
    }

    enum Layout {
        static let indeterminateArcLength: CGFloat = 0.72
        static let indeterminateRotationDuration: TimeInterval = 0.9
    }
}
