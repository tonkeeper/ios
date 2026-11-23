import SwiftUI
import UIKit

public extension View {
    @MainActor
    func tkNumPadKeyboard(presets: [TKNumPadPreset] = [], button: TKNumPadButton? = nil) -> some View {
        let isEnabled = TKNumPadView.isEnabled
        return keyboardType(.decimalPad)
            .overlay {
                if isEnabled {
                    NumPadInstaller(presets: presets, button: button).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
    }
}

private struct NumPadInstaller: UIViewRepresentable {
    let presets: [TKNumPadPreset]
    let button: TKNumPadButton?

    func makeUIView(context: Context) -> NumPadInstallerView {
        NumPadInstallerView()
    }

    func updateUIView(_ uiView: NumPadInstallerView, context: Context) {
        uiView.presets = presets
        uiView.button = button
        uiView.installIfNeeded()
    }
}

private final class NumPadInstallerView: UIView {
    var presets: [TKNumPadPreset] = [] {
        didSet { (textField?.inputView as? TKNumPadView)?.presets = presets }
    }

    var button: TKNumPadButton? {
        didSet { (textField?.inputView as? TKNumPadView)?.button = button }
    }

    private weak var textField: UITextField?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        installIfNeeded()
    }

    func installIfNeeded() {
        guard window != nil, !bounds.isEmpty, textField?.window == nil,
              let field = precedingTextField(), field.isUnder(self)
        else { return }
        textField = field
        let numPad = TKNumPadView(textField: field)
        numPad.presets = presets
        numPad.button = button
        field.inputView = numPad
        if field.isFirstResponder {
            field.reloadInputViews()
        }
    }

    private func precedingTextField() -> UITextField? {
        var child: UIView = self
        while let parent = child.superview, let index = parent.subviews.firstIndex(of: child) {
            for sibling in parent.subviews[..<index].reversed() {
                if let field = sibling.lastTextField {
                    return field
                }
            }
            child = parent
        }
        return nil
    }
}

private extension UIView {
    func isUnder(_ view: UIView) -> Bool {
        convert(bounds, to: nil).contains(view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil))
    }

    var lastTextField: UITextField? {
        if let field = self as? UITextField {
            return field
        }
        for subview in subviews.reversed() {
            if let field = subview.lastTextField {
                return field
            }
        }
        return nil
    }
}
