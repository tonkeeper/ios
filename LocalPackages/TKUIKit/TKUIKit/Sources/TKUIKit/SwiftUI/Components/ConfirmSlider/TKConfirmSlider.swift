import CoreHaptics
import SwiftUI
import TKLocalize
import UIKit

public struct TKConfirmSlider: View {
    public enum Appearance {
        case standard
        case warning
        case danger

        func handleColor(isEnabled: Bool) -> TKColor {
            switch self {
            case .standard: isEnabled ? .buttonPrimaryBackground : .buttonPrimaryBackgroundDisabled
            case .warning: .accentOrange.opacity(isEnabled ? 1 : Layout.disabledOpacity)
            case .danger: .accentRed.opacity(isEnabled ? 1 : Layout.disabledOpacity)
            }
        }
    }

    struct LabelStyle: Equatable {
        let opacity: CGFloat
        let offset: CGFloat
        let blur: CGFloat
    }

    struct ReturnTick: Equatable {
        let time: TimeInterval
        let progress: CGFloat
    }

    private enum Outcome {
        case success
        case failure

        init?(_ process: TKActionBarProcess) {
            switch process {
            case .success: self = .success
            case .failure: self = .failure
            case .idle, .processing: return nil
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.tkPalette) private var palette

    private let title = TKLocales.Actions.Confirm.swipe
    private let appearance: Appearance
    private let isEnabled: Bool
    private let process: TKActionBarProcess
    private let resetToken: Int
    private let handleAccessibilityIdentifier: String?
    private let onDragBegan: (() -> Void)?
    private let onDragAbandoned: (() -> Void)?
    private let onConfirm: () -> Void

    @State private var pull: CGFloat = 0
    @State private var dragStartPull: CGFloat?
    @State private var isPressed = false
    @State private var isArmed = false
    @State private var isCommitted = false
    @State private var isTrackHidden = false
    @State private var outcome: Outcome?
    @State private var checkTrim: CGFloat = 0
    @State private var shakeCycle: CGFloat = 0
    @StateObject private var haptics = SliderHaptics()

    public init(
        appearance: Appearance = .standard,
        isEnabled: Bool = true,
        process: TKActionBarProcess = .idle,
        resetToken: Int = 0,
        handleAccessibilityIdentifier: String? = nil,
        onDragBegan: (() -> Void)? = nil,
        onDragAbandoned: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.appearance = appearance
        self.isEnabled = isEnabled
        self.process = process
        self.resetToken = resetToken
        self.handleAccessibilityIdentifier = handleAccessibilityIdentifier
        self.onDragBegan = onDragBegan
        self.onDragAbandoned = onDragAbandoned
        self.onConfirm = onConfirm
        let isRunning = process != .idle
        _isCommitted = State(initialValue: isRunning)
        _isTrackHidden = State(initialValue: isRunning)
        _outcome = State(initialValue: Outcome(process))
        _checkTrim = State(initialValue: process == .success ? 1 : 0)
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let maxPull = Self.maxPull(width: width)
            let progress = Self.progress(pull: pull, maxPull: maxPull)
            let thumbFrame = thumbFrame(width: width, maxPull: maxPull)
            ZStack(alignment: .topLeading) {
                track
                    .frame(width: isCommitted ? Layout.height : width, height: Layout.height)
                    .offset(x: isCommitted ? (width - Layout.height) / 2 : 0)
                    .opacity(isTrackHidden ? 0 : 1)
                label(progress: progress)
                    .frame(width: width, height: Layout.height)
                thumb
                    .frame(width: thumbFrame.width, height: thumbFrame.height)
                    .modifier(ShakeEffect(cycle: shakeCycle, duration: Layout.shakeDuration))
                    .offset(x: thumbFrame.minX, y: thumbFrame.minY)
                if isCommitted {
                    resultContent
                        .frame(width: Layout.height, height: Layout.height)
                        .modifier(ShakeEffect(cycle: shakeCycle, duration: Layout.shakeDuration))
                        .offset(x: (width - Layout.height) / 2)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: Layout.spinnerFadeDuration)),
                            removal: .opacity.animation(.easeOut(duration: Layout.resultFadeOutDuration))
                        ))
                }
                HandlePanArea(
                    onPress: pressChanged,
                    onChanged: { dragChanged(by: $0, maxPull: maxPull) },
                    onEnded: { dragEnded(velocity: $0, maxPull: maxPull) },
                    onCancelled: { dragCancelled(maxPull: maxPull) }
                )
                .frame(width: thumbFrame.width, height: thumbFrame.height)
                .offset(x: thumbFrame.minX, y: thumbFrame.minY)
            }
        }
        .frame(height: Layout.height)
        .onChange(of: process, perform: processChanged)
        .onChange(of: resetToken) { _ in morphBack() }
    }

    static let height: CGFloat = 64

    static func maxPull(width: CGFloat) -> CGFloat {
        max(0, width - Layout.inset * 2 - Layout.thumbSize)
    }

    static func progress(pull: CGFloat, maxPull: CGFloat) -> CGFloat {
        maxPull > 0 ? min(pull, maxPull) / maxPull : 0
    }

    static func tickStep(pull: CGFloat) -> Int {
        Int(pull / Layout.tickDistance)
    }

    static func isArmed(wasArmed: Bool, progress: CGFloat) -> Bool {
        wasArmed ? progress >= Layout.disarmProgress : progress >= Layout.armProgress
    }

    static func shouldCommit(isArmed: Bool, progress: CGFloat, velocity: CGFloat) -> Bool {
        isArmed || (progress > Layout.flingProgress && velocity > Layout.flingVelocity)
    }

    static func labelStyle(isPressed: Bool, progress: CGFloat) -> LabelStyle {
        let fade = min(progress / Layout.labelHideProgress, 1)
        let baseOpacity = isPressed ? Layout.pressedLabelOpacity : 1
        return LabelStyle(
            opacity: baseOpacity * (1 - fade),
            offset: Layout.labelShift * fade,
            blur: Layout.labelBlur * fade
        )
    }

    static func landingTime(from pull: CGFloat) -> TimeInterval? {
        guard pull > 0 else { return nil }
        let travel = max(0, 1 - Layout.landingDistance / pull)
        return Layout.cancelDuration * Double(cancelTimeFraction(forTravel: travel))
    }

    static func returnTicks(from pull: CGFloat, maxPull: CGFloat) -> [ReturnTick] {
        guard pull > 0, maxPull > 0 else { return [] }
        let lastStep = Int(ceil(pull / Layout.tickDistance)) - 1
        guard lastStep > 0 else { return [] }
        return (1 ... lastStep).reversed().map { step in
            let boundary = CGFloat(step) * Layout.tickDistance
            let travelled = 1 - boundary / pull
            return ReturnTick(
                time: Layout.cancelDuration * Double(cancelTimeFraction(forTravel: travelled)),
                progress: boundary / maxPull
            )
        }
    }

    private static func cancelTimeFraction(forTravel travel: CGFloat) -> CGFloat {
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0 ..< 24 {
            let parameter = (low + high) / 2
            if bezier(parameter, Layout.cancelCurve.y1, Layout.cancelCurve.y2) < travel {
                low = parameter
            } else {
                high = parameter
            }
        }
        return bezier((low + high) / 2, Layout.cancelCurve.x1, Layout.cancelCurve.x2)
    }

    private static func bezier(_ parameter: CGFloat, _ first: CGFloat, _ second: CGFloat) -> CGFloat {
        let rest = 1 - parameter
        return 3 * rest * rest * parameter * first + 3 * rest * parameter * parameter * second + parameter * parameter * parameter
    }

    private func thumbFrame(width: CGFloat, maxPull: CGFloat) -> CGRect {
        if isCommitted {
            return CGRect(x: (width - Layout.height) / 2, y: 0, width: Layout.height, height: Layout.height)
        }
        return CGRect(
            x: Layout.inset,
            y: Layout.inset,
            width: Layout.thumbSize + min(pull, maxPull),
            height: Layout.thumbSize
        )
    }

    @ViewBuilder
    private var track: some View {
        if #available(iOS 26.0, *), TKLiquidGlass.isEnabled, !reduceTransparency {
            Color.clear
                .glassEffect(.regular.tint(TKColor.backgroundContent.opacity(Layout.trackTintOpacity).resolve(palette)), in: Capsule())
        } else {
            Capsule()
                .fill(.backgroundContent)
        }
    }

    private func label(progress: CGFloat) -> some View {
        let style = Self.labelStyle(isPressed: isPressed, progress: progress)
        return Text(title)
            .textStyle(.label1)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .overlay {
                if !reduceMotion {
                    SliderShimmer()
                        .mask {
                            Text(title)
                                .textStyle(.label1)
                                .lineLimit(1)
                        }
                }
            }
            .opacity(isCommitted ? 0 : style.opacity * (isEnabled ? 1 : Layout.disabledOpacity))
            .offset(x: style.offset)
            .blur(radius: style.blur)
            .padding(.horizontal, Layout.labelInset)
            .accessibilityHidden(true)
    }

    private var thumbColor: TKColor {
        switch outcome {
        case .success: .accentGreen
        case .failure: .accentRed
        case nil: appearance.handleColor(isEnabled: isEnabled || isCommitted)
        }
    }

    private var thumb: some View {
        thumbSurface
            .overlay(alignment: .trailing) {
                thumbContent
            }
            .disabled(!isEnabled)
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityAddTraits(isCommitted ? [] : .isButton)
            .accessibilityAction {
                guard isEnabled, !isCommitted else { return }
                onDragBegan?()
                commit()
            }
            .accessibilityIdentifier(handleAccessibilityIdentifier ?? "")
    }

    @ViewBuilder
    private var thumbSurface: some View {
        if #available(iOS 26.0, *), TKLiquidGlass.isEnabled, !reduceTransparency {
            Color.clear
                .glassEffect(.regular.tint(thumbColor.resolve(palette)), in: Capsule())
        } else {
            Capsule()
                .fill(thumbColor)
        }
    }

    private var thumbContent: some View {
        ZStack {
            icon(.TKUIKit.Icons.Size16.chevronRight)
                .modifier(IconFade(isShown: !isArmed))
            icon(.TKUIKit.Icons.Size16.doneBold)
                .modifier(IconFade(isShown: isArmed))
        }
        .frame(width: Layout.thumbSize, height: Layout.thumbSize)
        .opacity(isCommitted ? 0 : isEnabled ? 1 : Layout.disabledOpacity)
    }

    private var resultContent: some View {
        ZStack {
            if outcome == nil {
                CircularLoader(mode: .indeterminate, preset: .medium)
            }
            icon(.TKUIKit.Icons.Size16.doneBold)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: Layout.iconSize * checkTrim)
                }
            icon(.TKUIKit.Icons.Size16.close)
                .modifier(IconFade(isShown: outcome == .failure))
        }
        .accessibilityHidden(true)
    }

    private func icon(_ image: SwiftUI.Image) -> some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.iconPrimary)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .accessibilityHidden(true)
    }

    private func pressChanged(_ isPressed: Bool) {
        if isPressed {
            guard isEnabled, !isCommitted else { return }
            haptics.prepare()
        }
        withAnimation(.easeOut(duration: isPressed ? Layout.pressDuration : Layout.labelReturnDuration)) {
            self.isPressed = isPressed
        }
    }

    private func dragChanged(by translation: CGFloat, maxPull: CGFloat) {
        guard isEnabled, !isCommitted else { return }
        let currentPull = min(pull, maxPull)
        let startPull = dragStartPull ?? currentPull
        if dragStartPull == nil {
            dragStartPull = startPull
            haptics.startTension()
            onDragBegan?()
        }
        let newPull = min(max(0, startPull + translation), maxPull)
        let progress = Self.progress(pull: newPull, maxPull: maxPull)
        if Self.tickStep(pull: newPull) != Self.tickStep(pull: currentPull) {
            haptics.tick(progress: progress)
        }
        let armed = Self.isArmed(wasArmed: isArmed, progress: progress)
        if armed != isArmed {
            if armed {
                haptics.threshold()
            } else {
                haptics.disarm()
            }
            withAnimation(.easeInOut(duration: Layout.armDuration)) { isArmed = armed }
        }
        pull = newPull
    }

    private func dragEnded(velocity: CGFloat, maxPull: CGFloat) {
        guard dragStartPull != nil else { return }
        dragStartPull = nil
        let progress = Self.progress(pull: pull, maxPull: maxPull)
        if isEnabled, !isCommitted, maxPull > 0, Self.shouldCommit(isArmed: isArmed, progress: progress, velocity: velocity) {
            commit()
        } else {
            cancel(maxPull: maxPull)
        }
    }

    private func dragCancelled(maxPull: CGFloat) {
        guard dragStartPull != nil else { return }
        dragStartPull = nil
        cancel(maxPull: maxPull)
    }

    private func cancel(maxPull: CGFloat) {
        let returning = min(pull, maxPull)
        haptics.cancel(ticks: Self.returnTicks(from: returning, maxPull: maxPull), landingTime: Self.landingTime(from: returning))
        withAnimation(.timingCurve(0.2, 0.8, 0.3, 1, duration: Layout.cancelDuration)) {
            pull = 0
            isArmed = false
        }
        withAnimation(.easeOut(duration: Layout.labelReturnDuration)) { isPressed = false }
        onDragAbandoned?()
    }

    private func commit() {
        haptics.commit()
        morphIntoCircle()
        onConfirm()
    }

    private func morphIntoCircle() {
        if dragStartPull != nil {
            dragStartPull = nil
            haptics.cancel(ticks: [], landingTime: nil)
        }
        outcome = nil
        checkTrim = 0
        withAnimation(morphAnimation(.timingCurve(0.7, 0, 0.2, 1, duration: Layout.commitDuration))) {
            isCommitted = true
            isPressed = false
        }
        withAnimation(morphAnimation(.timingCurve(0.7, 0, 0.2, 1, duration: Layout.commitDuration * Layout.trackFadeShare))) {
            isTrackHidden = true
        }
    }

    private func processChanged(_ process: TKActionBarProcess) {
        if !isCommitted, process != .idle {
            morphIntoCircle()
        }
        guard isCommitted else { return }
        switch process {
        case .success:
            haptics.success()
            withAnimation(morphAnimation(.easeInOut(duration: Layout.successColorDuration))) { outcome = .success }
            withAnimation(morphAnimation(.easeOut(duration: Layout.checkmarkTrimDuration))) { checkTrim = 1 }
        case .failure:
            haptics.failure()
            withTransaction(Transaction(animation: nil)) { checkTrim = 0 }
            withAnimation(morphAnimation(.easeInOut(duration: Layout.failureColorDuration))) { outcome = .failure }
            if !reduceMotion {
                withAnimation(.linear(duration: Layout.shakeDuration)) { shakeCycle += 1 }
            }
        case .processing:
            withTransaction(Transaction(animation: nil)) { checkTrim = 0 }
            withAnimation(morphAnimation(.easeInOut(duration: Layout.failureColorDuration))) { outcome = nil }
        case .idle:
            morphBack()
        }
    }

    private func morphBack() {
        guard isCommitted else { return }
        withTransaction(Transaction(animation: nil)) { isArmed = false }
        withAnimation(morphAnimation(.timingCurve(0.65, 0, 0.25, 1, duration: Layout.morphBackDuration))) {
            isCommitted = false
            isTrackHidden = false
            outcome = nil
            pull = 0
        }
    }

    private func morphAnimation(_ animation: Animation) -> Animation {
        reduceMotion ? .linear(duration: Layout.reducedMotionDuration) : animation
    }

    private enum Layout {
        static let height: CGFloat = TKConfirmSlider.height
        static let inset: CGFloat = 4
        static let thumbSize: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let labelInset: CGFloat = 64
        static let labelShift: CGFloat = 22
        static let labelBlur: CGFloat = 3
        static let labelHideProgress: CGFloat = 0.6
        static let pressedLabelOpacity: CGFloat = 0.55
        static let disabledOpacity: CGFloat = 0.48
        static let trackTintOpacity: Double = 0.8
        static let tickDistance: CGFloat = 6
        static let armProgress: CGFloat = 0.88
        static let disarmProgress: CGFloat = 0.85
        static let flingProgress: CGFloat = 0.6
        static let flingVelocity: CGFloat = 1400
        static let pressDuration: TimeInterval = 0.16
        static let labelReturnDuration: TimeInterval = 0.5
        static let armDuration: TimeInterval = 0.18
        static let cancelDuration: TimeInterval = 0.46
        static let landingDistance: CGFloat = 0.5
        static let cancelCurve = (x1: CGFloat(0.2), y1: CGFloat(0.8), x2: CGFloat(0.3), y2: CGFloat(1))
        static let commitDuration: TimeInterval = 0.44
        static let trackFadeShare: TimeInterval = 0.6
        static let spinnerFadeDuration: TimeInterval = 0.3
        static let resultFadeOutDuration: TimeInterval = 0.12
        static let successColorDuration: TimeInterval = 0.25
        static let checkmarkTrimDuration: TimeInterval = 0.2
        static let failureColorDuration: TimeInterval = 0.2
        static let shakeDuration: CGFloat = 0.5
        static let morphBackDuration: TimeInterval = 0.36
        static let reducedMotionDuration: TimeInterval = 0.2
    }
}

private struct ShakeEffect: GeometryEffect {
    var cycle: CGFloat
    let duration: CGFloat

    var animatableData: CGFloat {
        get { cycle }
        set { cycle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let time = (cycle - cycle.rounded(.down)) * duration
        return ProjectionTransform(CGAffineTransform(translationX: 8 * exp(-6 * time) * sin(40 * time), y: 0))
    }
}

private struct IconFade: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown ? 1 : 0.8)
            .blur(radius: isShown ? 0 : 6)
    }
}

@MainActor
private final class SliderHaptics: ObservableObject {
    private var engine: CHHapticEngine?
    private var tension: CHHapticAdvancedPatternPlayer?
    private var returnPlayer: CHHapticPatternPlayer?
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        if engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true
        }
        try? engine?.start()
        lightImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }

    func startTension() {
        stopReturn()
        guard let engine, tension == nil else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0,
            duration: 30
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        tension = try? engine.makeAdvancedPlayer(with: pattern)
        setTension(progress: 0)
        try? tension?.start(atTime: CHHapticTimeImmediate)
    }

    func tick(progress: CGFloat) {
        let curve = Float(pow(progress, 1.6))
        if start([transient(intensity: 0.25 + 0.55 * curve, sharpness: 0.35 + 0.5 * curve)]) == nil {
            lightImpact.impactOccurred(intensity: CGFloat(0.25 + 0.55 * curve))
        }
        setTension(progress: progress)
    }

    func threshold() {
        if start([transient(intensity: 1, sharpness: 0.8), tail(intensity: 0.3, duration: 0.08)]) == nil {
            rigidImpact.impactOccurred(intensity: 1)
        }
    }

    func disarm() {
        lightImpact.impactOccurred(intensity: 0.5)
    }

    func cancel(ticks: [TKConfirmSlider.ReturnTick], landingTime: TimeInterval?) {
        stopTension()
        guard let landingTime else { return }
        let returning = ticks.map { tick in
            let curve = Float(pow(tick.progress, 1.6))
            return transient(intensity: 0.4 * (0.25 + 0.55 * curve), sharpness: 0.35 + 0.5 * curve, at: tick.time)
        }
        let landing = transient(intensity: 0.4, sharpness: 0.15, at: landingTime)
        returnPlayer = start(returning + [landing])
        if returnPlayer == nil {
            softImpact.impactOccurred(intensity: 0.4)
        }
    }

    func commit() {
        stopTension()
        stopReturn()
        if start([transient(intensity: 1, sharpness: 0.8), tail(intensity: 0.4, duration: 0.12)]) == nil {
            rigidImpact.impactOccurred(intensity: 1)
        }
    }

    func success() {
        notification.notificationOccurred(.success)
    }

    func failure() {
        notification.notificationOccurred(.error)
    }

    private func setTension(progress: CGFloat) {
        let intensity = Float(0.05 + 0.25 * pow(progress, 1.6))
        try? tension?.sendParameters(
            [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)],
            atTime: CHHapticTimeImmediate
        )
    }

    private func stopTension() {
        try? tension?.stop(atTime: CHHapticTimeImmediate)
        tension = nil
    }

    private func stopReturn() {
        try? returnPlayer?.stop(atTime: CHHapticTimeImmediate)
        returnPlayer = nil
    }

    private func start(_ events: [CHHapticEvent]) -> CHHapticPatternPlayer? {
        guard
            let engine,
            let pattern = try? CHHapticPattern(events: events, parameters: []),
            let player = try? engine.makePlayer(with: pattern),
            (try? player.start(atTime: CHHapticTimeImmediate)) != nil
        else { return nil }
        return player
    }

    private func transient(intensity: Float, sharpness: Float, at time: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func tail(intensity: Float, duration: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0.01,
            duration: duration
        )
    }
}

private struct HandlePanArea: UIViewRepresentable {
    let onPress: (Bool) -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let recognizer = PressPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        recognizer.onPress = { [weak coordinator = context.coordinator] in coordinator?.area?.onPress($0) }
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.area = self
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var area: HandlePanArea?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? PressPanGestureRecognizer else { return true }
            let movement = pan.movementFromPress
            return abs(movement.x) > abs(movement.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view?.next is UINavigationController
        }

        @objc func handlePan(_ recognizer: PressPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                area?.onChanged(recognizer.movementFromPress.x)
            case .ended:
                area?.onEnded(recognizer.velocity(in: recognizer.view).x)
            case .cancelled, .failed:
                area?.onCancelled()
            default:
                break
            }
        }
    }

    final class PressPanGestureRecognizer: UIPanGestureRecognizer {
        var onPress: ((Bool) -> Void)?
        private var pressLocation: CGPoint?

        var movementFromPress: CGPoint {
            guard let pressLocation else { return translation(in: view) }
            let location = location(in: view)
            return CGPoint(x: location.x - pressLocation.x, y: location.y - pressLocation.y)
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            guard pressLocation == nil, let touch = touches.first else { return }
            pressLocation = touch.location(in: view)
            onPress?(true)
        }

        override func reset() {
            super.reset()
            guard pressLocation != nil else { return }
            pressLocation = nil
            onPress?(false)
        }
    }
}

private struct SliderShimmer: UIViewRepresentable {
    func makeUIView(context: Context) -> SliderShimmerView {
        SliderShimmerView()
    }

    func updateUIView(_ uiView: SliderShimmerView, context: Context) {}
}

private final class SliderShimmerView: TKLayerAnimationView {
    private let glare: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.colors = [0, 0.35, 1, 0.35, 0].map { UIColor.white.withAlphaComponent($0).cgColor }
        layer.locations = [0, 0.3, 0.5, 0.7, 1]
        return layer
    }()

    private var sweptWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(glare)
        startAnimation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glare.bounds = CGRect(x: 0, y: 0, width: Self.glareWidth, height: bounds.height)
        glare.position = CGPoint(x: Self.sweepStart, y: bounds.midY)
        CATransaction.commit()
        if bounds.width != sweptWidth {
            sweptWidth = bounds.width
            restartAnimations()
        }
    }

    override func addAnimations() {
        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = Self.sweepStart
        sweep.toValue = sweptWidth + Self.sweepOvershoot
        sweep.duration = 1.6
        sweep.timingFunction = CAMediaTimingFunction(controlPoints: 0.37, 0, 0.63, 1)
        let cycle = CAAnimationGroup()
        cycle.animations = [sweep]
        cycle.duration = 2.4
        cycle.repeatCount = .infinity
        cycle.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        glare.add(cycle, forKey: Self.animationKey)
    }

    override func removeAnimations() {
        glare.removeAnimation(forKey: Self.animationKey)
    }

    private static let glareWidth: CGFloat = 120
    private static let sweepStart: CGFloat = -60
    private static let sweepOvershoot: CGFloat = 78
    private static let animationKey = "sweep"
}

public extension TKConfirmSlider.Appearance {
    init(_ appearance: TKSlider.Appearance) {
        switch appearance {
        case .standart: self = .standard
        case .warning: self = .warning
        case .danger: self = .danger
        }
    }
}

public extension TKActionBarProcess {
    init(_ state: TKProcessContainerView.State) {
        switch state {
        case .idle: self = .idle
        case .process: self = .processing
        case .success: self = .success
        case .failed: self = .failure
        }
    }
}
