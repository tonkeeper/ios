enum TonstakersAPIError: Error {
    case badRequest
    case badStatus(Int)
    case badResponse(Error)
    case transport(Error)
}
