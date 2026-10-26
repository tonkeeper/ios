enum KandelabrAPIError: Error {
    case badURL
    case badRequest
    case badStatus(Int)
    case badResponse(Error)
    case transport(Error)
}
