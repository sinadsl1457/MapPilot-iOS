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
}
