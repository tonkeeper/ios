enum EarnAPIError: Error {
    case badStatus(Int, code: String?)
    case badResponse(Error)
    case transport(Error)
}
