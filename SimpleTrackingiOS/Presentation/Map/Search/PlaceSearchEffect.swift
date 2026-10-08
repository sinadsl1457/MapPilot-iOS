import Foundation

enum PlaceSearchEffect: Equatable, Sendable {
    /// 검색 결과가 모두 보이도록 카메라를 맞춘다.
    case fitCamera([GeoPoint])
    /// 선택한 장소로 카메라를 옮긴다.
    case focus(GeoPoint)
    case showError(DomainError)
}
