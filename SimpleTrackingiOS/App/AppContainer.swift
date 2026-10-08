import Foundation

/// Composition root. 구현체를 만들고 생성자로 주입하는 곳은 여기 하나뿐이다.
@MainActor
final class AppContainer {
    let secrets: AppSecrets

    let searchPlaces: SearchPlacesUseCase
    let findRoute: FindRouteUseCase
    let observeLocation: ObserveLocationUseCase
    let getLocationPermission: GetLocationPermissionUseCase
    let requestLocationPermission: RequestLocationPermissionUseCase

    init(secrets: AppSecrets = .load(), session: URLSession = .shared) {
        self.secrets = secrets

        let apiClient = KakaoAPIClient(restAPIKey: secrets.kakaoRestAPIKey, session: session)
        let placeRepository = PlaceRepositoryImpl(client: apiClient)
        let routeRepository = RouteRepositoryImpl(client: apiClient)
        let locationRepository = LocationRepositoryImpl()

        searchPlaces = SearchPlacesUseCase(repository: placeRepository)
        findRoute = FindRouteUseCase(repository: routeRepository)
        observeLocation = ObserveLocationUseCase(repository: locationRepository)
        getLocationPermission = GetLocationPermissionUseCase(repository: locationRepository)
        requestLocationPermission = RequestLocationPermissionUseCase(repository: locationRepository)
    }

    func makeMapViewModel() -> MapViewModel {
        MapViewModel(
            observeLocation: observeLocation,
            getLocationPermission: getLocationPermission,
            requestLocationPermission: requestLocationPermission
        )
    }
}
