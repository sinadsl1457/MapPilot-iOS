import CoreLocation
import UIKit

/// 나침반: 폰이 향한 방향(진북 기준 각도). `CLLocationManager`의 heading 업데이트 래퍼.
/// 값이 초당 여러 번 바뀌어서 ViewModel을 거치지 않고 KakaoMapController가 바로 지도에 반영한다.
///
/// - 위치 권한·GPS 스트림은 LocationRepositoryImpl이 따로 관리한다. 여기서는 heading만 켠다.
/// - iOS는 센서 융합·떨림 보정·진북 변환을 OS가 해 준다. 진북(`trueHeading`)은 위치 권한이
///   있어야 나오고, 없으면 음수라 자북(`magneticHeading`)을 쓴다.
/// - `headingFilter`로 1° 넘게 바뀔 때만 받는다.
/// - 시뮬레이터에는 나침반이 없어서, 시뮬레이터 빌드에서만 북쪽(0°)을 한 번 보낸다(화살촉·콘이 그려지는지 확인용).
@MainActor
final class CompassHeading: NSObject {
    private let manager = CLLocationManager()
    private let onHeading: (Double) -> Void
    private var isRunning = false
    private var orientationObserver: NSObjectProtocol?

    init(onHeading: @escaping (Double) -> Void) {
        self.onHeading = onHeading
        super.init()
        manager.headingFilter = 1
        manager.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        #if targetEnvironment(simulator)
        startSimulatedHeading()
        #else
        guard CLLocationManager.headingAvailable() else { return }
        followDeviceOrientation()
        manager.startUpdatingHeading()
        isRunning = true
        #endif
    }

    func stop() {
        guard isRunning else { return }
        manager.stopUpdatingHeading()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        orientationObserver.map(NotificationCenter.default.removeObserver)
        orientationObserver = nil
        isRunning = false
    }

    /// 앱이 가로 화면도 지원해서, 방향의 기준(기기 윗변)을 기기 방향에 맞춘다.
    /// 그대로 두면 가로로 들었을 때 콘이 90° 틀어진다.
    private func followDeviceOrientation() {
        let device = UIDevice.current
        device.beginGeneratingDeviceOrientationNotifications()
        applyOrientation(device.orientation)
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyOrientation(UIDevice.current.orientation) }
        }
    }

    /// 시뮬레이터에는 나침반이 없어 화살촉·콘을 볼 수 없다. 북쪽을 한 번만 보낸다.
    /// 예전에는 12초에 한 바퀴 돌렸는데 마커가 계속 빙빙 돌아 거슬렸다.
    /// `#if targetEnvironment(simulator)` 안에서만 불려서 실기기 앱에는 영향이 없다.
    private func startSimulatedHeading() {
        onHeading(0)
        isRunning = true
    }

    /// 눕히거나(faceUp/faceDown) 모를 때는 직전 기준을 유지한다. 두 enum은 raw 값이 같다.
    private func applyOrientation(_ orientation: UIDeviceOrientation) {
        guard orientation.isPortrait || orientation.isLandscape,
              let heading = CLDeviceOrientation(rawValue: Int32(orientation.rawValue)) else { return }
        manager.headingOrientation = heading
    }
}

extension CompassHeading: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // 정확도가 음수면 측정 실패(보정 필요 등)라 버린다.
        guard newHeading.headingAccuracy >= 0 else { return }
        onHeading(newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading)
    }
}
