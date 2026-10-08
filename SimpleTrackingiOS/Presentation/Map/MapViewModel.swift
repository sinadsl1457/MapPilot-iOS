import Foundation
import Observation

@MainActor
@Observable
final class MapViewModel {
    static let myLocationZoom = 17

    private(set) var hasLocationPermission = false
    private(set) var myLocation: UserLocation?
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

    func onMyLocationButtonTapped() {
        guard hasLocationPermission else {
            effectContinuation.yield(.requestLocationPermission)
            return
        }
        if let myLocation {
            effectContinuation.yield(.moveCamera(myLocation.point, zoom: Self.myLocationZoom))
        } else {
            effectContinuation.yield(.showMessage(String(
                localized: "map.message.findingLocation",
                defaultValue: "현재 위치를 찾고 있어요"
            )))
        }
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
            effectContinuation.yield(.moveCamera(location.point, zoom: Self.myLocationZoom))
        }
    }

    private func handleLocationFailure(_ error: any Error) {
        locationTask = nil
        guard !(error is CancellationError) else { return }
        hasLocationPermission = false
        myLocation = nil
        effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
    }

    /// 테스트 전용: 현재 위치 스트림이 끝날 때까지 기다린다.
    func waitForLocationUpdates() async {
        await locationTask?.value
    }
}
