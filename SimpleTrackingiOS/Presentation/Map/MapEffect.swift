import Foundation

/// 화면이 한 번만 처리하는 이벤트. 상태가 아니므로 `MapViewModel.effects`로 흘려보낸다.
enum MapEffect: Equatable, Sendable {
    case moveCamera(GeoPoint, zoom: Int)
    case showError(DomainError)
    case showMessage(String)
    case requestLocationPermission
}
