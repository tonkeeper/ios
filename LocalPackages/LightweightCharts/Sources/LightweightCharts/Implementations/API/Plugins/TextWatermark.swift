import Foundation

/**
 Handle to a text watermark primitive created on a chart pane.

 Use this handle to update watermark options or detach (remove) the watermark.
 */
@MainActor
public class TextWatermark {
    typealias Context = JavaScriptEvaluator

    let jsName: String
    private weak var context: Context?

    init(context: Context?, jsName: String) {
        self.context = context
        self.jsName = jsName
    }

    /**
     Update the watermark with new options.

     - Parameter options: New options to apply to the watermark.
     */
    public func applyOptions(_ options: TextWatermarkOptions) {
        guard let context = context else { return }
        let script = "window['\(jsName)'].applyOptions(\(options.jsonString()));"
        context.submitScript(script)
    }

    /**
     Update the watermark with a partial options patch.

     - Parameter options: New partial options to apply to the watermark.
     */
    public func applyOptions(_ options: TextWatermarkUpdateOptions) {
        guard let context = context else { return }
        let script = "window['\(jsName)'].applyOptions(\(options.jsonString()));"
        context.submitScript(script)
    }

    /**
     Remove (detach) the watermark from the chart.

     After calling this method, the watermark is removed from the chart
     and the handle should no longer be used.
     */
    public func detach() {
        guard let context = context else { return }
        let script = "window['\(jsName)'].detach();"
        context.submitScript(script)
    }
}
