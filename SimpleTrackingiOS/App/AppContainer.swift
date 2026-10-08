import Foundation

/// Composition root. 구현체를 만들고 생성자로 주입하는 곳은 여기 하나뿐이다.
@MainActor
final class AppContainer {
    let secrets: AppSecrets

    let searchPlaces: SearchPlacesUseCase
    let searchPlacesByCategory: SearchPlacesByCategoryUseCase
    let recentSearches: RecentSearchesUseCase
    let findRoute: FindRouteUseCase
    let findWalkingRoute: FindWalkingRouteUseCase
    let findTransitRoutes: FindTransitRoutesUseCase
    let observeLocation: ObserveLocationUseCase
    let getLocationPermission: GetLocationPermissionUseCase
    let requestLocationPermission: RequestLocationPermissionUseCase

    init(secrets: AppSecrets = .load(), session: URLSession = .shared) {
        self.secrets = secrets

        let apiClient = KakaoAPIClient(restAPIKey: secrets.kakaoRestAPIKey, session: session)
        let placeRepository = PlaceRepositoryImpl(client: apiClient)
        let routeRepository = RouteRepositoryImpl(client: apiClient)
        let locationRepository: any LocationRepository = if let fixed = secrets.fixedLocation {
            FixedLocationRepository(point: fixed)
        } else {
            LocationRepositoryImpl()
        }

        searchPlaces = SearchPlacesUseCase(repository: placeRepository)
        searchPlacesByCategory = SearchPlacesByCategoryUseCase(repository: placeRepository)
        recentSearches = RecentSearchesUseCase(repository: UserDefaultsRecentSearchRepository())
        findRoute = FindRouteUseCase(repository: routeRepository)
        findWalkingRoute = FindWalkingRouteUseCase(repository: routeRepository)
        findTransitRoutes = FindTransitRoutesUseCase(repository: routeRepository)
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

    func makeRouteViewModel() -> RouteViewModel {
        RouteViewModel(findCarRoute: findRoute, findWalkingRoute: findWalkingRoute, findTransitRoutes: findTransitRoutes)
    }

    func makePlaceSearchViewModel() -> PlaceSearchViewModel {
        PlaceSearchViewModel(
            searchPlaces: searchPlaces,
            searchPlacesByCategory: searchPlacesByCategory,
            recentSearches: recentSearches
        )
    }
}
