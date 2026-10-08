import Foundation

/// 최근 검색어를 기기 안(UserDefaults)에만 저장한다.
struct UserDefaultsRecentSearchRepository: RecentSearchRepository {
    static let key = "recentSearchQueries"

    // UserDefaults는 스레드 안전하지만 Sendable로 표시되어 있지 않다.
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() async -> [String] {
        defaults.stringArray(forKey: Self.key) ?? []
    }

    func save(_ queries: [String]) async {
        defaults.set(queries, forKey: Self.key)
    }
}
