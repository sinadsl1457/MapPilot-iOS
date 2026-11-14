import Foundation
import Observation

/// 지도에 표시할 검색 결과 하나. SDK 타입을 쓰지 않는다.
struct PlaceMarker: Equatable, Sendable {
    let id: String
    let point: GeoPoint
    /// 목록 순번(1부터).
    let number: Int
}

/// 지도에 그릴 경로 선 한 구간. 종류마다 색이 다르다.
struct RouteLine: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case car, walk, bus, subway
    }

    let kind: Kind
    let points: [GeoPoint]
}

/// 지도에 그릴 경로 전체: 선들과 출발·도착 마커 위치.
struct RouteOverlay: Equatable, Sendable {
    let lines: [RouteLine]
    let start: GeoPoint
    let end: GeoPoint

    var allPoints: [GeoPoint] { [start] + lines.flatMap(\.points) + [end] }
}

/// 카메라를 여러 지점에 맞출 때 앱 UI가 지도를 가리는 높이(pt). 지점은 그 안쪽에 보이게 맞춘다.
/// 위: 상단 UI(검색창·칩 또는 길찾기 카드·탭), 아래: 시트가 멈출 높이 또는 경로 카드 높이.
struct MapInsets: Equatable, Sendable {
    var top: CGFloat
    var bottom: CGFloat
}

/// 지도에 내리는 명령. `KakaoMapController`가 구현하고, 테스트에서는 fake로 바꾼다.
@MainActor
protocol KakaoMapCommands: AnyObject {
    /// animated가 false면 애니메이션 없이 바로 놓는다(내 위치로 갈 때).
    func moveCamera(to point: GeoPoint, zoom: Int, animated: Bool)
    func fitCamera(to points: [GeoPoint], insets: MapInsets)
    func updateMyLocation(_ location: UserLocation?)
    func showPlaceMarkers(_ markers: [PlaceMarker], selectedID: String?)
    /// 경로 선과 출발·도착 마커. nil이면 지운다.
    func showRoute(_ overlay: RouteOverlay?)
    /// 카메라가 내 위치를 따라가게 한다. 실제 추적은 SDK 트래킹이 한다.
    func setFollowMode(_ mode: FollowMode)
}

/// SwiftUI(선언형)와 지도 SDK(명령형) 사이의 다리.
/// 엔진이 준비되기 전에 들어온 명령은 보관했다가 지도가 붙는 순간 실행한다.
@MainActor
@Observable
final class KakaoMapState {
    /// 인증·지도 로드 실패 사유. nil이면 정상.
    private(set) var loadFailure: String?
    /// 지도 화면 중심 좌표. 카메라가 멈출 때마다 갱신된다.
    @ObservationIgnored private(set) var cameraCenter: GeoPoint?
    /// 사용자가 검색 결과 마커를 탭했을 때(장소 id).
    @ObservationIgnored var onPlaceTapped: ((String) -> Void)?
    /// 사용자가 손으로 지도를 드래그하거나 돌렸을 때. 코드로 옮긴 카메라는 오지 않는다.
    @ObservationIgnored var onUserGesture: ((MapGesture) -> Void)?

    @ObservationIgnored private weak var map: (any KakaoMapCommands)?
    @ObservationIgnored private var pendingCamera: PendingCamera?
    @ObservationIgnored private var myLocation: UserLocation?
    @ObservationIgnored private var placeMarkers: [PlaceMarker] = []
    @ObservationIgnored private var selectedPlaceID: String?
    @ObservationIgnored private var routeOverlay: RouteOverlay?
    @ObservationIgnored private var followMode = FollowMode.none

    private enum PendingCamera {
        case move(GeoPoint, zoom: Int, animated: Bool)
        case fit([GeoPoint], MapInsets)
    }

    var isMapReady: Bool { map != nil }

    func moveCamera(to point: GeoPoint, zoom: Int, animated: Bool = true) {
        if let map {
            map.moveCamera(to: point, zoom: zoom, animated: animated)
        } else {
            // 준비 전에 여러 번 들어오면 마지막 명령만 의미가 있다.
            pendingCamera = .move(point, zoom: zoom, animated: animated)
        }
    }

    func fitCamera(to points: [GeoPoint], insets: MapInsets) {
        guard !points.isEmpty else { return }
        if let map {
            map.fitCamera(to: points, insets: insets)
        } else {
            pendingCamera = .fit(points, insets)
        }
    }

    func updateMyLocation(_ location: UserLocation?) {
        myLocation = location
        map?.updateMyLocation(location)
    }

    func showPlaceMarkers(_ markers: [PlaceMarker], selectedID: String?) {
        placeMarkers = markers
        selectedPlaceID = selectedID
        map?.showPlaceMarkers(markers, selectedID: selectedID)
    }

    func showRoute(_ overlay: RouteOverlay?) {
        routeOverlay = overlay
        map?.showRoute(overlay)
    }

    func setFollowMode(_ mode: FollowMode) {
        followMode = mode
        map?.setFollowMode(mode)
    }

    // MARK: - KakaoMapController 전용

    func attach(_ map: any KakaoMapCommands) {
        self.map = map
        loadFailure = nil
        map.updateMyLocation(myLocation)
        map.setFollowMode(followMode)
        map.showPlaceMarkers(placeMarkers, selectedID: selectedPlaceID)
        map.showRoute(routeOverlay)
        switch pendingCamera {
        case let .move(point, zoom, animated): map.moveCamera(to: point, zoom: zoom, animated: animated)
        case let .fit(points, insets): map.fitCamera(to: points, insets: insets)
        case nil: break
        }
        pendingCamera = nil
    }

    func detach() {
        map = nil
    }

    func fail(_ reason: String) {
        loadFailure = reason
    }

    func cameraDidStop(at center: GeoPoint) {
        cameraCenter = center
    }

    func placeMarkerTapped(id: String) {
        onPlaceTapped?(id)
    }

    func userDidGesture(_ gesture: MapGesture) {
        onUserGesture?(gesture)
    }
}
