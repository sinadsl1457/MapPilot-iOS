import Foundation

/// 최근 검색어. 가장 최근 것이 앞에 오고, 같은 검색어는 한 번만, 최대 `maxCount`개까지 둔다.
struct RecentSearchesUseCase: Sendable {
    static let maxCount = 10

    private let repository: any RecentSearchRepository

    init(repository: any RecentSearchRepository) {
        self.repository = repository
    }

    func list() async -> [String] {
        await repository.load()
    }

    @discardableResult
    func add(_ query: String) async -> [String] {
        let normalized = QueryNormalizer.normalize(query)
        guard !normalized.isEmpty else { return await repository.load() }
        var queries = await repository.load().filter { $0 != normalized }
        queries.insert(normalized, at: 0)
        queries = Array(queries.prefix(Self.maxCount))
        await repository.save(queries)
        return queries
    }

    @discardableResult
    func remove(_ query: String) async -> [String] {
        let queries = await repository.load().filter { $0 != query }
        await repository.save(queries)
        return queries
    }

    func clear() async {
        await repository.save([])
    }
}
