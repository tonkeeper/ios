import Foundation

public enum PaginationEvent<T> {
  case cached([T])
  case loading
  case empty
  case loaded([T])
  case nextPage([T])
  case pageLoading
  case pageLoadingFailed
}
