import SwiftUI

@main
struct SimpleTrackingApp: App {
    @State private var container: AppContainer
    @State private var mapViewModel: MapViewModel
    @State private var placeSearchViewModel: PlaceSearchViewModel
    @State private var routeViewModel: RouteViewModel

    init() {
        let container = AppContainer()
        _container = State(initialValue: container)
        _mapViewModel = State(initialValue: container.makeMapViewModel())
        _placeSearchViewModel = State(initialValue: container.makePlaceSearchViewModel())
        _routeViewModel = State(initialValue: container.makeRouteViewModel())
    }

    var body: some Scene {
        WindowGroup {
            MapScreen(
                kakaoNativeAppKey: container.secrets.kakaoNativeAppKey,
                viewModel: mapViewModel,
                search: placeSearchViewModel,
                route: routeViewModel
            )
        }
    }
}
