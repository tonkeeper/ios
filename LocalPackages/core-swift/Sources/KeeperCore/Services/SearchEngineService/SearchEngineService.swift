import Foundation

public protocol SearchEngineServiceProtocol {
  func loadSuggestions(searchText: String, searchEngine: SearchEngine) async throws -> [String]
  func composeSearchURL(input: String, searchEngine: SearchEngine) -> URL?
}

public final class SearchEngineService: SearchEngineServiceProtocol {

  struct DuckSuggestModel: Codable {
    let phrase: String
  }

  private let session: URLSession

  public init(session: URLSession) {
    self.session = session
  }

  public func loadSuggestions(searchText: String, searchEngine: SearchEngine) async throws -> [String] {
    switch searchEngine {
    case .duckduckgo:
      try await fetchDuckSuggestions(searchText: searchText)
    case .google:
      try await fetchGoogleSuggestions(searchText: searchText)
    }
  }

  public func composeSearchURL(input: String, searchEngine: SearchEngine) -> URL? {
    switch searchEngine {
    case .duckduckgo:
      return URL(string: "https://duckduckgo.com/?q=\(input)")
    case .google:
      return URL(string: "https://www.google.com/search?q=\(input)")
    }
  }

  private func fetchGoogleSuggestions(searchText: String) async throws -> [String] {
    let stringURL = "https://suggestqueries.google.com/complete/search?q=\(searchText)&client=firefox"
    guard let url = URL(string: stringURL) else {
      return []
    }

    let (data, _) = try await session.data(from: url)
    guard let response = try? JSONSerialization.jsonObject(with: data) as? [Any],
          response.count > 1,
          let sugesstions = response[1] as? [String] else {
      return []
    }

    return sugesstions
  }

  private func fetchDuckSuggestions(searchText: String) async throws -> [String] {
    let stringURL = "https://duckduckgo.com/ac/?kl=wt-wt&q=\(searchText)"
    guard let url = URL(string: stringURL) else {
      return []
    }

    let (data, _) = try await session.data(from: url)
    guard let response = try? JSONDecoder().decode([DuckSuggestModel].self, from: data) else {
      return []
    }
    let mappedStringValues = response.compactMap { $0.phrase }
    return mappedStringValues
  }
}
