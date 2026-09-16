import SwiftUI

/// Crossfades content when `key` changes: the previous content keeps rendering in a
/// top-aligned overlay (out of layout) and fades out, while the new content fades in.
/// Opacity only — neither side moves or scales.
///
/// `value` is snapshotted at the moment of transition so the outgoing content is built
/// from the data it was last rendered with, even after the parent's state moved on.
///
/// `shouldAnimate` gates each key change with the (outgoing, incoming) values: when it
/// returns `false`, the content is swapped instantly — no fades, identity still resets.
public struct ShelfCrossfadeView<Key: Hashable, Value, Content: View>: View {
    private let key: Key
    private let value: Value
    private let configuration: ShelfTransitionConfiguration
    private let shouldAnimate: (Value, Value) -> Bool
    private let content: (Value) -> Content

    @State private var stash = Stash()
    @State private var outgoing: OutgoingSnapshot?

    public init(
        key: Key,
        value: Value,
        configuration: ShelfTransitionConfiguration = .default,
        shouldAnimate: @escaping (Value, Value) -> Bool = { _, _ in true },
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.key = key
        self.value = value
        self.configuration = configuration
        self.shouldAnimate = shouldAnimate
        self.content = content
    }

    public var body: some View {
        let startsHidden = stash.record(key: key, value: value, shouldAnimate: shouldAnimate)
        return FadeInView(
            startsHidden: startsHidden,
            animation: configuration.fadeInAnimation,
            opacityTracker: stash
        ) {
            content(value)
        }
        .transition(.identity)
        .id(key)
        .allowsHitTesting(outgoing == nil)
        .overlay(alignment: .top) {
            if let outgoing {
                FadeOutView(
                    initialOpacity: outgoing.initialOpacity,
                    animation: configuration.fadeOutAnimation
                ) {
                    content(outgoing.value)
                }
                .transition(.identity)
                .id(outgoing.id)
            }
        }
        .onChange(of: key) { newKey in
            beginTransition(to: newKey)
        }
        .task(id: outgoing?.id) {
            await removeOutgoingWhenFaded()
        }
    }

    private func beginTransition(to newKey: Key) {
        // Body normally runs before onChange; fall back to the rendered value in case
        // the change is observed before the new key has been rendered.
        let snapshotValue: Value?
        if stash.renderedKey == newKey {
            snapshotValue = stash.transitionKey == newKey ? stash.previousValue : nil
        } else if let renderedValue = stash.renderedValue, shouldAnimate(renderedValue, value) {
            snapshotValue = renderedValue
        } else {
            snapshotValue = nil
        }
        guard let snapshotValue else {
            outgoing = nil
            return
        }
        outgoing = OutgoingSnapshot(
            value: snapshotValue,
            initialOpacity: min(max(stash.baseOpacity, 0), 1)
        )
    }

    private func removeOutgoingWhenFaded() async {
        guard outgoing != nil else { return }
        let lifetime = configuration.fadeOutDuration + 0.05
        try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
        guard !Task.isCancelled else { return }
        outgoing = nil
    }
}

private extension ShelfCrossfadeView {
    struct OutgoingSnapshot: Identifiable {
        let id = UUID()
        let value: Value
        let initialOpacity: Double
    }

    /// Render-time bookkeeping that must survive body evaluations without triggering
    /// invalidation: the last rendered key/value pair (to snapshot the outgoing state),
    /// and the presentation opacity of the incoming layer (to hand off smoothly when a
    /// transition is interrupted mid-fade).
    final class Stash: FadeOpacityTracker {
        private(set) var renderedKey: Key?
        private(set) var renderedValue: Value?
        private(set) var previousValue: Value?
        private(set) var transitionKey: Key?
        var baseOpacity: Double = 1

        func record(key: Key, value: Value, shouldAnimate: (Value, Value) -> Bool) -> Bool {
            if let renderedKey, renderedKey != key {
                if let renderedValue, shouldAnimate(renderedValue, value) {
                    previousValue = renderedValue
                    transitionKey = key
                } else {
                    previousValue = nil
                    transitionKey = nil
                }
            }
            renderedKey = key
            renderedValue = value
            return transitionKey == key
        }
    }
}

private protocol FadeOpacityTracker: AnyObject {
    var baseOpacity: Double { get set }
}

private struct FadeInView<Content: View>: View {
    private let animation: Animation
    private let opacityTracker: FadeOpacityTracker
    private let content: Content

    @State private var opacity: Double

    init(
        startsHidden: Bool,
        animation: Animation,
        opacityTracker: FadeOpacityTracker,
        @ViewBuilder content: () -> Content
    ) {
        self.animation = animation
        self.opacityTracker = opacityTracker
        self.content = content()
        _opacity = State(initialValue: startsHidden ? 0 : 1)
    }

    var body: some View {
        content
            .modifier(TrackedOpacityModifier(opacity: opacity, tracker: opacityTracker))
            .onAppear {
                guard opacity < 1 else { return }
                withAnimation(animation) {
                    opacity = 1
                }
            }
    }
}

/// Applies opacity while reporting the per-frame presentation value to the tracker,
/// so an interrupted fade-in can be picked up by the outgoing snapshot at the exact
/// opacity it visually had.
private struct TrackedOpacityModifier: ViewModifier, Animatable {
    var opacity: Double
    var tracker: FadeOpacityTracker

    var animatableData: Double {
        get { opacity }
        set {
            opacity = newValue
            tracker.baseOpacity = newValue
        }
    }

    func body(content: Content) -> some View {
        content.opacity(opacity)
    }
}

private struct FadeOutView<Content: View>: View {
    private let animation: Animation
    private let content: Content

    @State private var opacity: Double

    init(
        initialOpacity: Double,
        animation: Animation,
        @ViewBuilder content: () -> Content
    ) {
        self.animation = animation
        self.content = content()
        _opacity = State(initialValue: initialOpacity)
    }

    var body: some View {
        content
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(animation) {
                    opacity = 0
                }
            }
    }
}
