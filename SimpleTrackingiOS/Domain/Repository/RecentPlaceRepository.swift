import Foundation

/// 최근 장소 저장소. 순서·개수 규칙은 `RecentPlacesUseCase`가 정한다.
protocol RecentPlaceRepository: Sendable {
    func load() async -> [RecentPlace]
    func save(_ places: [RecentPlace]) async
}
