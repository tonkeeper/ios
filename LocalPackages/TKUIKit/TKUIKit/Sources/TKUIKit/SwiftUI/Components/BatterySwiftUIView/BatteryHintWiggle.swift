import SwiftUI

public extension View {
    /// Shakes the view now and then to hint that it can be tapped.
    func batteryHintWiggle(isActive: Bool) -> some View {
        modifier(BatteryHintWiggleModifier(isActive: isActive))
    }
}

/// The hint is for new users: the app turns it on for the session it was installed in,
/// and off once the user opens the battery.
public final class BatteryHintAvailability: ObservableObject {
    public static let shared = BatteryHintAvailability()

    @Published public var isAvailable = false
}

enum BatteryHintWiggle {
    struct Frame: Equatable {
        let angle: CGFloat
        let scale: CGFloat
    }

    static let pause: TimeInterval = 0.6
    static let duration: TimeInterval = 0.65
    static let period: TimeInterval = 2.4

    private enum Easing {
        case easeOut
        case easeInOut

        func callAsFunction(_ x: CGFloat) -> CGFloat {
            switch self {
            case .easeOut: 1 - (1 - x) * (1 - x)
            case .easeInOut: x * x * (3 - 2 * x)
            }
        }
    }

    private struct Key {
        let time: CGFloat
        let value: CGFloat
        let easing: Easing
    }

    private static let angleKeys: [Key] = [
        Key(time: 0, value: 0, easing: .easeOut),
        Key(time: 0.08, value: 12, easing: .easeInOut),
        Key(time: 0.18, value: -10, easing: .easeInOut),
        Key(time: 0.28, value: 8, easing: .easeInOut),
        Key(time: 0.38, value: -6, easing: .easeInOut),
        Key(time: 0.48, value: 3, easing: .easeOut),
        Key(time: 0.6, value: 0, easing: .easeOut),
    ]

    private static let scaleKeys: [Key] = [
        Key(time: 0, value: 1, easing: .easeOut),
        Key(time: 0.12, value: 1.12, easing: .easeInOut),
        Key(time: 0.65, value: 1, easing: .easeOut),
    ]

    /// The shake at `progress` (0...1) of its `duration`; the angle is in degrees.
    static func frame(at progress: CGFloat) -> Frame {
        let time = min(max(progress, 0), 1) * CGFloat(duration)
        return Frame(angle: value(at: time, keys: angleKeys), scale: value(at: time, keys: scaleKeys))
    }

    private static func value(at time: CGFloat, keys: [Key]) -> CGFloat {
        guard let next = keys.firstIndex(where: { $0.time > time }) else {
            return keys.last?.value ?? 0
        }
        guard next > 0 else { return keys[next].value }
        let from = keys[next - 1]
        let to = keys[next]
        let x = (time - from.time) / (to.time - from.time)
        return from.value + (to.value - from.value) * from.easing(x)
    }
}

private struct BatteryHintWiggleModifier: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var availability = BatteryHintAvailability.shared
    @State private var shakes: CGFloat = 0

    private var isPlaying: Bool {
        isActive && availability.isAvailable && !reduceMotion
    }

    func body(content: Content) -> some View {
        content
            .modifier(BatteryHintWiggleEffect(shakes: shakes))
            .task(id: isPlaying) {
                guard isPlaying else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.nanoseconds(BatteryHintWiggle.pause))
                    guard !Task.isCancelled else { return }
                    withAnimation(.linear(duration: BatteryHintWiggle.duration)) {
                        shakes += 1
                    }
                    try? await Task.sleep(
                        nanoseconds: Self.nanoseconds(BatteryHintWiggle.period - BatteryHintWiggle.pause)
                    )
                }
            }
    }

    private static func nanoseconds(_ interval: TimeInterval) -> UInt64 {
        UInt64(interval * 1_000_000_000)
    }
}

/// Animates a growing count of shakes: each whole step plays one shake, and a whole count is at rest.
private struct BatteryHintWiggleEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let frame = BatteryHintWiggle.frame(at: shakes - shakes.rounded(.down))
        let transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .rotated(by: frame.angle * .pi / 180)
            .scaledBy(x: frame.scale, y: frame.scale)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}
