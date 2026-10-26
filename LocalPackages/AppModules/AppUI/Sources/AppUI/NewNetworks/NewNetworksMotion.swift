import CoreGraphics
import Foundation

/// The design's geometry and motion. The Figma frame is 390×844 and every size below is scaled
/// together with the orbit; the timings are the design's, in seconds.
enum NewNetworksMotion {
    static let orbitSize: CGFloat = 368
    /// The middle ring carries the icons.
    static let iconOrbitRadius: CGFloat = 136
    static let iconMaxSize: CGFloat = 64
    static let iconMinSize: CGFloat = 36
    /// A page-coloured border keeps an icon off the ring it sits on.
    static let iconBorderWidth: CGFloat = 4
    static let logoSize: CGFloat = 100
    /// From the vertical centre of the screen.
    static let orbitCenterOffset: CGFloat = -92
    static let textCenterOffset: CGFloat = 162
    static let confettiTop: CGFloat = 40
    static let confettiHeight: CGFloat = 474
    /// The Lottie halves are bottom-anchored in an 844pt frame.
    static let confettiAreaTop: CGFloat = 168
    static let confettiHalfAspectRatio: CGFloat = 187 / 540
    static let confettiRise: CGFloat = 60
    /// The first icon sits top-left like in the design, the rest follow clockwise.
    static let firstIconAngle: Double = -135
    /// Same height as the large button that replaces the loader, so the bar doesn't jump.
    static let loaderRowHeight: CGFloat = 56
    static let flyOutBlurRadius: CGFloat = 14

    static let ringsDelay = 0.15
    static let ringsDuration = 0.8
    static let logoDipDelay = 0.1
    static let logoDipDuration = 0.2
    static let logoDipScale = 0.94
    static let logoRecoverDuration = 0.35
    static let flyDelay = 0.25
    static let flyDuration = 0.7

    /// While loading the orbit turns calmly: once per `loopTurnDuration`, reached by a short t²
    /// speed-up that starts while the icons are still flying out.
    static let spinStartDelay = 0.6
    static let spinUpDuration = 0.8
    static let loopTurnDuration = 5.7
    static let loopSpeed = 360 / loopTurnDuration
    /// t² ends exactly at the loop speed.
    static let spinUpDegrees = loopSpeed * spinUpDuration / 2

    /// The finish is the orbit's turn from the design (one revolution in 4.8s on
    /// cubic-bezier(0.65, 0, 0.15, 1)), picked up where its speed equals the loop speed: 24.28% of
    /// the time, 7.58% of the turn. From there it speeds up to ~308°/s in ~0.8s, then slows down
    /// for ~2.8s.
    static let designTurnDuration = 4.8
    static let finishFromTime = 0.2428
    static let finishFromProgress = 0.0758
    static let finishDuration = designTurnDuration * (1 - finishFromTime)
    static let finishDegrees = 360 * (1 - finishFromProgress)

    /// The result starts when the orbit visibly stops: with under 3° to go, the last 0.5s of the
    /// slow-down reads as standing still. Same as in the design.
    static let revealBeforeStop = 0.5
    static let colorInDuration = 0.5
    static let popDuration = 0.18
    static let popScale = 1.15
    static let logoPopDuration = 0.2
    static let logoPopScale = 1.08
    static let confettiDuration = 1.1
    static let breathingHalfPeriod = 2.0
    static let breathingScale = 1.02
    /// The springs are at rest by then and the orbit stops redrawing.
    static let settleDuration = 1.5

    static func scale(for size: CGSize) -> CGFloat {
        min(1, (size.width - 22) / orbitSize, size.height / 760)
    }

    /// 64pt up to four chains, then shrinking with the count so a crowded orbit still breathes.
    static func iconSize(count: Int) -> CGFloat {
        guard count > 4 else { return iconMaxSize }
        return min(iconMaxSize, max(iconMinSize, iconMaxSize * sqrt(4 / CGFloat(count))))
    }

    /// 60ms between icons as in the design, squeezed so a long list still finishes in time.
    static func stagger(count: Int) -> Double {
        count <= 5 ? 0.06 : 0.24 / Double(count - 1)
    }

    /// The design's spring (damping ratio 0.45, stiffness 500), released from rest at `from`.
    static func spring(from: Double, to: Double, elapsed: Double) -> Double {
        guard elapsed > 0 else { return from }
        let dampingRatio = 0.45
        let frequency = sqrt(500.0)
        let dampedFrequency = frequency * sqrt(1 - dampingRatio * dampingRatio)
        let decay = exp(-dampingRatio * frequency * elapsed)
        let phase = dampedFrequency * elapsed
        return to + (from - to) * decay * (cos(phase) + dampingRatio * frequency / dampedFrequency * sin(phase))
    }
}

/// `cubic-bezier(x1, y1, x2, y2)` as CSS and Figma define it.
struct CubicBezierEasing {
    /// Figma's Easy Ease — fly-out, fades and every state swap.
    static let standard = CubicBezierEasing(0.33, 0, 0.67, 1)
    static let designTurn = CubicBezierEasing(0.65, 0, 0.15, 1)

    private let x1: Double
    private let y1: Double
    private let x2: Double
    private let y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    func callAsFunction(_ progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        return bezier(y1, y2, parameter(for: progress))
    }

    /// The curve's coordinate for `t`, with the end points at 0 and 1.
    private func bezier(_ a: Double, _ b: Double, _ t: Double) -> Double {
        3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
    }

    private func parameter(for x: Double) -> Double {
        var t = x
        for _ in 0 ..< 8 {
            let difference = bezier(x1, x2, t) - x
            let slope = 3 * (1 - t) * (1 - t) * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t * t * (1 - x2)
            guard abs(difference) > 1e-6, slope > 1e-6 else { break }
            t -= difference / slope
        }
        return min(1, max(0, t))
    }
}

/// Where the orbit is at a moment. The intro starts at `start`; the loop spins up from `loop`;
/// `finish`, once set, takes the rotation from the loop speed into the resting layout, which N
/// evenly spaced icons repeat every 360/N degrees, and the result follows.
struct NewNetworksOrbitTimeline {
    struct Loop {
        var start: Date
        var baseRotation: Double
        var delay: Double
    }

    struct Finish {
        var start: Date
        var fromRotation: Double
        var toRotation: Double
    }

    let start: Date
    private(set) var loop: Loop
    private(set) var finish: Finish?

    init(start: Date) {
        self.start = start
        loop = Loop(start: start, baseRotation: 0, delay: NewNetworksMotion.spinStartDelay)
    }

    /// The moment the result shows: text and buttons swap, the added icons colour in, confetti drops.
    var revealDate: Date? {
        finish.map { $0.start + NewNetworksMotion.finishDuration - NewNetworksMotion.revealBeforeStop }
    }

    func rings(at date: Date) -> Double {
        eased(since: start, delay: NewNetworksMotion.ringsDelay, duration: NewNetworksMotion.ringsDuration, at: date)
    }

    func breathing(at date: Date) -> Double {
        let halfPeriod = NewNetworksMotion.breathingHalfPeriod
        let phase = date.timeIntervalSince(start).truncatingRemainder(dividingBy: 2 * halfPeriod) / halfPeriod
        let progress = phase < 1 ? phase : 2 - phase
        return 1 + (NewNetworksMotion.breathingScale - 1) * CubicBezierEasing.standard(progress)
    }

    func fly(index: Int, count: Int, at date: Date) -> Double {
        eased(
            since: start,
            delay: NewNetworksMotion.flyDelay + Double(index) * NewNetworksMotion.stagger(count: count),
            duration: NewNetworksMotion.flyDuration,
            at: date
        )
    }

    func rotation(at date: Date) -> Double {
        guard let finish else { return loopRotation(at: date) }
        let progress = date.timeIntervalSince(finish.start) / NewNetworksMotion.finishDuration
        guard progress > 0 else { return finish.fromRotation }
        guard progress < 1 else { return finish.toRotation }
        return finish.fromRotation + (finish.toRotation - finish.fromRotation) * Self.finishEasing(progress)
    }

    func logoScale(at date: Date) -> Double {
        if let reveal = revealElapsed(at: date) {
            guard reveal < NewNetworksMotion.logoPopDuration else {
                return NewNetworksMotion.spring(
                    from: NewNetworksMotion.logoPopScale,
                    to: 1,
                    elapsed: reveal - NewNetworksMotion.logoPopDuration
                )
            }
            return 1 + (NewNetworksMotion.logoPopScale - 1) * CubicBezierEasing.standard(reveal / NewNetworksMotion.logoPopDuration)
        }
        let elapsed = date.timeIntervalSince(start) - NewNetworksMotion.logoDipDelay
        guard elapsed > 0 else { return 1 }
        if elapsed < NewNetworksMotion.logoDipDuration {
            return 1 - (1 - NewNetworksMotion.logoDipScale) * CubicBezierEasing.standard(elapsed / NewNetworksMotion.logoDipDuration)
        }
        let recovery = elapsed - NewNetworksMotion.logoDipDuration
        guard recovery < NewNetworksMotion.logoRecoverDuration else { return 1 }
        return NewNetworksMotion.logoDipScale
            + (1 - NewNetworksMotion.logoDipScale) * CubicBezierEasing.standard(recovery / NewNetworksMotion.logoRecoverDuration)
    }

    /// How far an added icon has turned from grey to colour.
    func colored(at date: Date) -> Double {
        guard let reveal = revealElapsed(at: date) else { return 0 }
        return CubicBezierEasing.standard(reveal / NewNetworksMotion.colorInDuration)
    }

    /// An added icon's pulse along with the colour.
    func pop(at date: Date) -> Double {
        guard let reveal = revealElapsed(at: date) else { return 1 }
        guard reveal < NewNetworksMotion.popDuration else {
            return NewNetworksMotion.spring(from: NewNetworksMotion.popScale, to: 1, elapsed: reveal - NewNetworksMotion.popDuration)
        }
        return 1 + (NewNetworksMotion.popScale - 1) * CubicBezierEasing.standard(reveal / NewNetworksMotion.popDuration)
    }

    func isSettled(at date: Date) -> Bool {
        guard let finish else { return false }
        return date.timeIntervalSince(finish.start) > NewNetworksMotion.finishDuration + NewNetworksMotion.settleDuration
    }

    /// The distance is stretched or squeezed to the nearest resting layout (at most half a gap,
    /// ±13% speed with four icons).
    mutating func startFinish(at date: Date, count: Int) {
        let from = rotation(at: date)
        let period = 360 / Double(max(count, 1))
        let to = ((from + NewNetworksMotion.finishDegrees) / period).rounded() * period
        finish = Finish(start: date, fromRotation: from, toRotation: to)
    }

    /// Back to loading (a retry): the loop spins up again from where the orbit stands.
    mutating func restartLoop(at date: Date) {
        loop = Loop(start: date, baseRotation: rotation(at: date), delay: 0)
        finish = nil
    }

    private func revealElapsed(at date: Date) -> Double? {
        guard let revealDate, date >= revealDate else { return nil }
        return date.timeIntervalSince(revealDate)
    }

    private func loopRotation(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(loop.start) - loop.delay
        guard elapsed > 0 else { return loop.baseRotation }
        guard elapsed > NewNetworksMotion.spinUpDuration else {
            return loop.baseRotation + NewNetworksMotion.spinUpDegrees * pow(elapsed / NewNetworksMotion.spinUpDuration, 2)
        }
        return loop.baseRotation
            + NewNetworksMotion.spinUpDegrees
            + NewNetworksMotion.loopSpeed * (elapsed - NewNetworksMotion.spinUpDuration)
    }

    private static func finishEasing(_ progress: Double) -> Double {
        let turn = CubicBezierEasing.designTurn(
            NewNetworksMotion.finishFromTime + progress * (1 - NewNetworksMotion.finishFromTime)
        )
        return (turn - NewNetworksMotion.finishFromProgress) / (1 - NewNetworksMotion.finishFromProgress)
    }

    private func eased(since: Date, delay: Double, duration: Double, at date: Date) -> Double {
        CubicBezierEasing.standard((date.timeIntervalSince(since) - delay) / duration)
    }
}
