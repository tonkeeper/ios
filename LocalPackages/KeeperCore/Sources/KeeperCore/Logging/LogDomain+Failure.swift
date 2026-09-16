import TKLogging

public extension LogDomain {
    /// Reports a failed operation, except when the app cancelled it itself — a superseded search,
    /// the next keystroke, a screen that went away. Those still leave a trace, because "the request
    /// never finished" and "the request was dropped" look identical in a log otherwise, but they
    /// are not warnings and would drown the real ones.
    func failure(
        _ message: @autoclosure () -> String,
        error: any Error,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        guard error.isCancelledError else {
            w(message(), file: file, function: function, line: line, error: error, extraInfo: extraInfo)
            return
        }
        i("\(message()) - cancelled", file: file, function: function, line: line, extraInfo: extraInfo)
    }
}
