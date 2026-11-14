import Foundation
import Observation

/// 내 위치와 위치 권한, 따라가기 모드. 실제 카메라 추적은 지도(KakaoMapController의 SDK 트래킹)가 한다.
@MainActor
@Observable
final class MapViewModel {
    static let myLocationZoom = 17

    private(set) var hasLocationPermission = false
    private(set) var myLocation: UserLocation?
    private(set) var followMode = FollowMode.none
    /// 카메라가 내 위치에 맞춰져 있다(첫 위치 이동 · 내 위치 버튼 이후 지도를 옮기지 않음).
    /// false면 내 위치 버튼은 카메라만 옮기고, true면 따라가기를 켠다.
    private(set) var isCameraOnMyLocation = false
    /// 권한이 이미 거부된 상태에서 요청하면 설정 앱으로 안내한다. alert가 닫히면 View가 false로 돌려놓는다.
    var isSettingsAlertPresented = false

    /// 구독자는 하나(View)라고 가정한다. 구독 전에 나온 이벤트는 버퍼에 남는다.
    let effects: AsyncStream<MapEffect>

    @ObservationIgnored private let effectContinuation: AsyncStream<MapEffect>.Continuation
    @ObservationIgnored private let observeLocation: ObserveLocationUseCase
    @ObservationIgnored private let getLocationPermission: GetLocationPermissionUseCase
    @ObservationIgnored private let requestPermission: RequestLocationPermissionUseCase
    @ObservationIgnored private var locationTask: Task<Void, Never>?
    @ObservationIgnored private var hasMovedToFirstLocation = false

    init(
        observeLocation: ObserveLocationUseCase,
        getLocationPermission: GetLocationPermissionUseCase,
        requestLocationPermission: RequestLocationPermissionUseCase
    ) {
        self.observeLocation = observeLocation
        self.getLocationPermission = getLocationPermission
        self.requestPermission = requestLocationPermission
        (effects, effectContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        locationTask?.cancel()
        effectContinuation.finish()
    }

    // MARK: - View 이벤트

    /// 화면이 처음 나타날 때. 권한이 아직 결정되지 않았으면 바로 요청한다.
    func onAppear() async {
        let permission = await getLocationPermission()
        if permission == .notDetermined {
            effectContinuation.yield(.requestLocationPermission)
        } else {
            apply(permission)
        }
    }

    /// 앱이 다시 활성화될 때. 사용자가 설정 앱에서 권한을 바꿨을 수 있다.
    func onBecameActive() async {
        apply(await getLocationPermission())
    }

    /// 앱이 백그라운드로 가면 GPS를 끈다. 백그라운드 위치는 쓰지 않는다.
    func onEnteredBackground() {
        stopObservingLocation()
    }

    /// 권한 없음 → 권한 요청 / 위치 모름 → 안내 /
    /// 지도를 옮겨 둠 → 내 위치로 카메라만 옮긴다(따라가기는 아직 끔) /
    /// 카메라가 내 위치 → 따라가기 모드를 다음 단계로(none → follow → followWithHeading → none).
    /// none에서 누를 때는 항상 내 위치로 카메라를 옮긴다.
    func onMyLocationButtonTapped() {
        guard hasLocationPermission else {
            effectContinuation.yield(.requestLocationPermission)
            return
        }
        guard let myLocation else {
            effectContinuation.yield(.showMessage(String(
                localized: "map.message.findingLocation",
                defaultValue: "현재 위치를 찾고 있어요"
            )))
            return
        }
        if followMode == .none {
            effectContinuation.yield(.moveCamera(myLocation.point, zoom: Self.myLocationZoom))
            if !isCameraOnMyLocation {
                isCameraOnMyLocation = true
                return
            }
        }
        followMode = followMode.next
    }

    /// 사용자가 지도를 드래그했다. 내 위치로 카메라를 끌고 가지 않게 따라가기를 끈다.
    /// 다음 내 위치 버튼은 카메라만 옮긴다.
    func onMapPanned() {
        stopFollowing()
    }

    /// 사용자가 지도를 직접 돌렸다. 회전 모드만 풀고 따라가기는 유지한다.
    func onMapRotated() {
        if followMode == .followWithHeading { followMode = .follow }
    }

    /// 다른 기능이 카메라를 옮길 때(검색 결과, 길찾기) 화면이 부른다.
    /// 끄지 않으면 트래킹이 카메라를 바로 내 위치로 되돌린다.
    func stopFollowing() {
        followMode = .none
        isCameraOnMyLocation = false
    }

    /// `.requestLocationPermission` 효과를 받은 View가 호출한다.
    func requestLocationPermission() async {
        if await getLocationPermission() == .denied {
            isSettingsAlertPresented = true
            return
        }
        apply(await requestPermission())
    }

    // MARK: - 위치 구독

    private func apply(_ permission: LocationPermission) {
        hasLocationPermission = permission == .authorized
        if hasLocationPermission {
            startObservingLocation()
        } else {
            stopObservingLocation()
            myLocation = nil
            stopFollowing()
        }
    }

    private func startObservingLocation() {
        guard locationTask == nil else { return }
        let stream = observeLocation()
        locationTask = Task { [weak self] in
            do {
                for try await location in stream {
                    self?.receive(location)
                }
                self?.locationTask = nil
            } catch {
                self?.handleLocationFailure(error)
            }
        }
    }

    private func stopObservingLocation() {
        locationTask?.cancel()
        locationTask = nil
    }

    private func receive(_ location: UserLocation) {
        myLocation = location
        if !hasMovedToFirstLocation {
            hasMovedToFirstLocation = true
            isCameraOnMyLocation = true
            effectContinuation.yield(.moveCamera(location.point, zoom: Self.myLocationZoom))
        }
    }

    private func handleLocationFailure(_ error: any Error) {
        locationTask = nil
        guard !(error is CancellationError) else { return }
        hasLocationPermission = false
        myLocation = nil
        stopFollowing()
        effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
    }

    /// 테스트 전용: 현재 위치 스트림이 끝날 때까지 기다린다.
    func waitForLocationUpdates() async {
        await locationTask?.value
    }
}
