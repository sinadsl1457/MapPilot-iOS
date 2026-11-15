import Foundation

extension DomainError {
    /// 사용자에게 보여줄 문구. `default`를 쓰지 않아 새 case가 생기면 컴파일 에러가 난다.
    var userMessage: String {
        switch self {
        case .network: String(localized: "error.network")
        case .unauthorized: String(localized: "error.unauthorized")
        case .quotaExceeded: String(localized: "error.quotaExceeded")
        case .server: String(localized: "error.server")
        case .emptyQuery: String(localized: "error.emptyQuery")
        case .destinationTooClose: String(localized: "error.destinationTooClose")
        case .routeNotFound: String(localized: "error.routeNotFound")
        case .locationPermissionDenied: String(localized: "error.locationPermissionDenied")
        case .unknown: String(localized: "error.unknown")
        }
    }
}
