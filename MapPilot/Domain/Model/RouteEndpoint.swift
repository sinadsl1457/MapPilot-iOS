import Foundation

/// 길찾기 출발지·도착지. 내 위치이거나 검색한 장소다.
enum RouteEndpoint: Equatable, Sendable {
    /// 좌표는 길찾기를 시작하는 순간의 내 위치로 정한다(RouteViewModel).
    case myLocation
    case place(Place)

    /// 이 지점의 좌표. 내 위치는 `myLocation`을 쓰고, 아직 모르면 nil.
    func point(myLocation: GeoPoint?) -> GeoPoint? {
        switch self {
        case .myLocation: myLocation
        case let .place(place): place.location
        }
    }
}
