@MainActor
protocol BrowserConnectedModuleOutput: AnyObject {
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
}
