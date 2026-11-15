import Foundation

enum DomainError: Error, Equatable {
    case network
    case unauthorized
    case quotaExceeded
    case server(code: Int)
    case emptyQuery
    case destinationTooClose
    case routeNotFound(reason: String)
    case locationPermissionDenied
    case unknown
}
