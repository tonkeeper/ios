public protocol RemoteConfigProvider {
    func load() async
    subscript(_ flag: String) -> Bool? { get }
}
