@preconcurrency import KakaoMapsSDK
import SwiftUI

/// KMViewContainer를 SwiftUI에 올린다. 카메라·마커 명령은 `state`로 보낸다.
struct KakaoMapView: UIViewRepresentable {
    let appKey: String
    let state: KakaoMapState
    /// scenePhase가 active일 때만 true. 엔진은 앱이 활성일 때만 돌아야 한다.
    let isActive: Bool

    func makeCoordinator() -> KakaoMapController {
        KakaoMapController(appKey: appKey, state: state)
    }

    func makeUIView(context: Context) -> KMViewContainer {
        context.coordinator.makeContainer()
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: KakaoMapController) {
        coordinator.tearDown()
    }
}
