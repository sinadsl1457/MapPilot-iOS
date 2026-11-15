import Foundation

struct SearchPlacesByCategoryUseCase: Sendable {
    static let radiusMeters = 1_000

    private let repository: any PlaceRepository

    init(repository: any PlaceRepository) {
        self.repository = repository
    }

    func callAsFunction(_ category: PlaceCategory, around center: GeoPoint) async throws -> [Place] {
        try await repository.searchPlaces(category: category, center: center, radiusMeters: Self.radiusMeters)
    }
}
