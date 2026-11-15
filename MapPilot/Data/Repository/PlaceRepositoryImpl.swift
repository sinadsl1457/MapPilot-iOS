import Foundation

struct PlaceRepositoryImpl: PlaceRepository {
    private let client: KakaoAPIClient

    init(client: KakaoAPIClient) {
        self.client = client
    }

    func searchPlaces(query: String, center: GeoPoint?) async throws -> [Place] {
        try await client.searchKeyword(query: query, center: center)
            .documents
            .compactMap(PlaceMapper.map)
    }

    func searchPlaces(category: PlaceCategory, center: GeoPoint, radiusMeters: Int) async throws -> [Place] {
        try await client.searchCategory(code: PlaceCategoryMapper.kakaoCode(category), center: center, radiusMeters: radiusMeters)
            .documents
            .compactMap(PlaceMapper.map)
    }
}
