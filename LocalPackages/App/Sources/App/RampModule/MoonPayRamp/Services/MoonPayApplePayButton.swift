import MoonPay
import UIKit

/// The MoonPay Apple Pay button frame the ramp screen shows in place of Continue, and the payment
/// a tap on it starts.
@MainActor
final class MoonPayApplePayButton {
    var onReady: (() -> Void)?
    var onPress: (() -> Void)?
    var onFailToLoad: ((MoonPayFrameError) -> Void)?
    /// The payment ended or the frame failed: a new attempt needs a new button.
    var onFinish: (() -> Void)?

    let controller: MoonPayFrameViewController
    let updates: AsyncStream<MoonPayPaymentUpdate>
    /// Ours for the payment the button starts.
    let externalTransactionId: String
    private(set) var quote: MoonPayBuyQuote
    /// The frame rendered the button; before that it shows nothing.
    private(set) var isReady = false
    private(set) var isPressed = false

    private let finishUpdates: () -> Void
    private var isFinished = false

    init(
        controller: MoonPayFrameViewController,
        quote: MoonPayBuyQuote,
        externalTransactionId: String,
        updates: AsyncStream<MoonPayPaymentUpdate>,
        finishUpdates: @escaping () -> Void
    ) {
        self.controller = controller
        self.quote = quote
        self.externalTransactionId = externalTransactionId
        self.updates = updates
        self.finishUpdates = finishUpdates
    }

    /// Hands the frame a newer quote, so it does not reload when the old one expires.
    func setQuote(_ quote: MoonPayBuyQuote) {
        guard !isPressed, !isFinished, quote.signature != self.quote.signature else { return }
        self.quote = quote
        controller.send(.setQuote(signature: quote.signature))
    }

    func markReady() {
        guard !isReady else { return }
        isReady = true
        onReady?()
    }

    func press() {
        guard !isPressed, !isFinished else { return }
        isPressed = true
        onPress?()
    }

    func failToLoad(_ error: MoonPayFrameError) {
        onFailToLoad?(error)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish?()
    }

    /// Drops a button the screen no longer shows, before anyone paid with it.
    func discard() {
        onReady = nil
        onPress = nil
        onFailToLoad = nil
        onFinish = nil
        finishUpdates()
    }
}
