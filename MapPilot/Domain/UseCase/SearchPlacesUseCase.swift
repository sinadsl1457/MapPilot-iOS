import Foundation

struct SearchPlacesUseCase: Sendable {
    private let repository: any PlaceRepository

    init(repository: any PlaceRepository) {
        self.repository = repository
    }

    /// 앞뒤 공백을 지우고 연속된 공백을 하나로 줄인 뒤 검색한다.
    func callAsFunction(query: String, center: GeoPoint? = nil) async throws -> [Place] {
        let normalized = QueryNormalizer.normalize(query)
        guard !normalized.isEmpty else { throw DomainError.emptyQuery }
        return try await repository.searchPlaces(query: normalized, center: center)
    }
}
