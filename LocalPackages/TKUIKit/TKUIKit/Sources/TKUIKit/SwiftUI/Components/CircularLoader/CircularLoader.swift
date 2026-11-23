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
    /// The share of the ring the indeterminate arc covers.
    var spinnerArcLength: CGFloat
    var spinnerTurnDuration: TimeInterval

    public init(
        lineWidth: CGFloat,
        progressColor: Color,
        trackColor: Color,
        size: CGSize,
        contentPadding: CGFloat,
        spinnerArcLength: CGFloat = 0.72,
        spinnerTurnDuration: TimeInterval = 0.9
    ) {
        self.lineWidth = lineWidth
        self.progressColor = progressColor
        self.trackColor = trackColor
        self.size = size
        self.contentPadding = contentPadding
        self.spinnerArcLength = spinnerArcLength
        self.spinnerTurnDuration = spinnerTurnDuration
    }
}

public struct CircularLoader: View {
    @Environment(\.tkPalette) private var palette

    public var mode: CircularLoaderMode
    public var duration: TimeInterval
    /// When the countdown started. Loaders given the same date show one timer; without it the
    /// countdown starts when the loader appears or restarts.
    public var startDate: Date?
    public var onComplete: () -> Void
    public var restartToken: Int
    public var preset: CircularLoaderPreset

    @State private var appearanceDate = Date()
    @State private var didComplete = false
    @State private var foregroundCount = 0

    public init(
        mode: CircularLoaderMode = .determinate,
        preset: CircularLoaderPreset,
        duration: TimeInterval = 10,
        startDate: Date? = nil,
        onComplete: @escaping () -> Void = {},
        restartToken: Int = 0
    ) {
        self.mode = mode
        self.duration = duration
        self.startDate = startDate
        self.onComplete = onComplete
        self.restartToken = restartToken
        self.preset = preset
    }

    private var configuration: CircularLoaderConfiguration {
        preset.configuration(palette: palette)
    }

    public var body: some View {
        CircularLoaderLayer(timing: timing, configuration: configuration)
            .aspectRatio(1, contentMode: .fit)
            .padding(configuration.contentPadding)
            .frame(width: configuration.size.width, height: configuration.size.height)
            .onChange(of: identity) { _ in
                appearanceDate = Date()
                didComplete = false
            }
            // The sleep runs on uptime, which stops while the device sleeps: reschedule it from the wall clock.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                if completionDate != nil { foregroundCount += 1 }
            }
            .task(id: CompletionSchedule(date: completionDate, foregroundCount: foregroundCount)) {
                await completeWhenDue()
            }
    }
}

private extension CircularLoader {
    struct Identity: Hashable {
        let mode: CircularLoaderMode
        let duration: TimeInterval
        let startDate: Date?
        let restartToken: Int
    }

    struct CompletionSchedule: Equatable {
        let date: Date?
        let foregroundCount: Int
    }

    var identity: Identity {
        Identity(
            mode: mode,
            duration: duration,
            startDate: startDate,
            restartToken: restartToken
        )
    }

    var timing: CircularLoaderLayerView.Timing {
        CircularLoaderLayerView.Timing(mode: mode, duration: duration, startDate: startDate ?? appearanceDate)
    }

    var completionDate: Date? {
        guard mode == .determinate else { return nil }
        guard duration > 0 else { return .distantPast }
        return timing.startDate.addingTimeInterval(duration)
    }

    func completeWhenDue() async {
        guard let completionDate else { return }
        let delay = completionDate.timeIntervalSinceNow
        if delay > 0 {
            guard (try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))) != nil else { return }
        }
        guard !Task.isCancelled, !didComplete else { return }
        didComplete = true
        onComplete()
    }
}
