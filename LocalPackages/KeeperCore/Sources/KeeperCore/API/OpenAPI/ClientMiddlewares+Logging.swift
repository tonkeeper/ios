import OpenAPIRuntime

extension [any ClientMiddleware] {
    /// Single construction point for generated-client middleware stacks, so no API ends up
    /// without request-level logs. Logging goes outermost: it then also sees whatever the
    /// middlewares below it throw.
    static func logged(_ middlewares: [any ClientMiddleware] = []) -> [any ClientMiddleware] {
        [APILoggingMiddleware()] + middlewares
    }
}
