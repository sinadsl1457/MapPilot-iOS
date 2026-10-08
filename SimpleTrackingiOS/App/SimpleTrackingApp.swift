import SwiftUI

@main
struct SimpleTrackingApp: App {
    @State private var container: AppContainer
    @State private var mapViewModel: MapViewModel

    init() {
        let container = AppContainer()
        _container = State(initialValue: container)
        _mapViewModel = State(initialValue: container.makeMapViewModel())
    }

    var body: some Scene {
        WindowGroup {
            MapScreen(kakaoNativeAppKey: container.secrets.kakaoNativeAppKey, viewModel: mapViewModel)
        }
    }
}
