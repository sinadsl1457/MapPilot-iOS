import Foundation

/// 최근 검색어 저장소. 순서·개수 규칙은 `RecentSearchesUseCase`가 정한다.
protocol RecentSearchRepository: Sendable {
    func load() async -> [String]
    func save(_ queries: [String]) async
}
