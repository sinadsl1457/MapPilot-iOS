import Foundation
import Observation

/// 지도에 내리는 명령. `KakaoMapController`가 구현하고, 테스트에서는 fake로 바꾼다.
@MainActor
protocol KakaoMapCommands: AnyObject {
    func moveCamera(to point: GeoPoint, zoom: Int)
    func updateMyLocation(_ location: UserLocation?)
}

/// SwiftUI(선언형)와 지도 SDK(명령형) 사이의 다리.
/// 엔진이 준비되기 전에 들어온 명령은 보관했다가 지도가 붙는 순간 실행한다.
@MainActor
@Observable
final class KakaoMapState {
    /// 인증·지도 로드 실패 사유. nil이면 정상.
    private(set) var loadFailure: String?

    @ObservationIgnored private weak var map: (any KakaoMapCommands)?
    @ObservationIgnored private var pendingCamera: (point: GeoPoint, zoom: Int)?
    @ObservationIgnored private var myLocation: UserLocation?

    var isMapReady: Bool { map != nil }

    func moveCamera(to point: GeoPoint, zoom: Int) {
        if let map {
            map.moveCamera(to: point, zoom: zoom)
        } else {
            // 준비 전에 여러 번 들어오면 마지막 명령만 의미가 있다.
            pendingCamera = (point, zoom)
        }
    }

    func updateMyLocation(_ location: UserLocation?) {
        myLocation = location
        map?.updateMyLocation(location)
    }

    // MARK: - KakaoMapController 전용

    func attach(_ map: any KakaoMapCommands) {
        self.map = map
        loadFailure = nil
        map.updateMyLocation(myLocation)
        if let pendingCamera {
            self.pendingCamera = nil
            map.moveCamera(to: pendingCamera.point, zoom: pendingCamera.zoom)
        }
    }

    func detach() {
        map = nil
    }

    func fail(_ reason: String) {
        loadFailure = reason
    }
}
