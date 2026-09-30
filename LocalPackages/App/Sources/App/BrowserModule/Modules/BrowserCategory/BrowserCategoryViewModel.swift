protocol BrowserCategoryModuleOutput: AnyObject {
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
    var didTapSearch: (() -> Void)? { get set }
}
