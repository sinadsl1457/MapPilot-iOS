import Foundation

/// Composition root. 구현체를 만들고 생성자로 주입하는 곳은 여기 하나뿐이다.
@MainActor
final class AppContainer {
    let secrets: AppSecrets

    let searchPlaces: SearchPlacesUseCase
    let searchPlacesByCategory: SearchPlacesByCategoryUseCase
    let recentSearches: RecentSearchesUseCase
    let recentPlaces: RecentPlacesUseCase
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
        let locationRepository = LocationRepositoryImpl()

        searchPlaces = SearchPlacesUseCase(repository: placeRepository)
        searchPlacesByCategory = SearchPlacesByCategoryUseCase(repository: placeRepository)
        recentSearches = RecentSearchesUseCase(repository: UserDefaultsRecentSearchRepository())
        recentPlaces = RecentPlacesUseCase(repository: UserDefaultsRecentPlaceRepository())
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
            recentSearches: recentSearches,
            recentPlaces: recentPlaces
        )
    }

    /// 길찾기 준비 화면이 열릴 때마다 새로 만든다. `mode`는 지난 길찾기에서 고른 이동 수단.
    func makeRoutePlannerViewModel(mode: TravelMode) -> RoutePlannerViewModel {
        RoutePlannerViewModel(mode: mode, recentPlaces: recentPlaces)
    }

    /// 출발지·도착지 선택 페이지가 열릴 때마다 새로 만든다.
    func makeEndpointSearchViewModel() -> EndpointSearchViewModel {
        EndpointSearchViewModel(searchPlaces: searchPlaces, recentSearches: recentSearches, recentPlaces: recentPlaces)
    }
}
