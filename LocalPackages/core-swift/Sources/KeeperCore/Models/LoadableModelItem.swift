import Foundation

public enum LoadableModelItem<T> {
  case loading
  case value(T)
}
