import Foundation

/// 화면이 한 번만 처리하는 이벤트. 상태가 아니므로 `MapViewModel.effects`로 흘려보낸다.
enum MapEffect: Equatable, Sendable {
    /// 내 위치로 카메라를 옮긴다(첫 위치, 내 위치 버튼). 화면은 애니메이션 없이 바로 놓는다.
    case moveCamera(GeoPoint, zoom: Int)
    case showError(DomainError)
    case showMessage(String)
    case requestLocationPermission
}
