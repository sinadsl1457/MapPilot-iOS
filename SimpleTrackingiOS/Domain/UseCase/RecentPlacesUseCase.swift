import Foundation

/// 최근에 고른 장소. 가장 최근 것이 앞에 오고, 같은 장소(id)는 한 번만, 최대 `maxCount`개까지 둔다.
/// 기록하는 곳: PlaceSearchViewModel.select(장소 상세를 봄), EndpointSearchViewModel.remember(출발지·도착지로 고름),
/// RoutePlannerViewModel.chooseRecent(최근 장소를 다시 고름)
struct RecentPlacesUseCase: Sendable {
    static let maxCount = 20

    private let repository: any RecentPlaceRepository

    init(repository: any RecentPlaceRepository) {
        self.repository = repository
    }

    func list() async -> [RecentPlace] {
        await repository.load()
    }

    @discardableResult
    func add(_ place: Place, now: Date = .now) async -> [RecentPlace] {
        let others = await repository.load().filter { $0.place.id != place.id }
        let places = Array(([RecentPlace(place: place, usedAt: now)] + others).prefix(Self.maxCount))
        await repository.save(places)
        return places
    }

    func remove(placeID: String) async -> [RecentPlace] {
        let places = await repository.load().filter { $0.place.id != placeID }
        await repository.save(places)
        return places
    }
}
