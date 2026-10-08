import Foundation

struct RouteRepositoryImpl: RouteRepository {
    private let client: KakaoAPIClient

    init(client: KakaoAPIClient) {
        self.client = client
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        let response = try await client.directions(from: origin, to: destination)
        guard let route = response.routes.first else {
            throw DomainError.routeNotFound(reason: "경로 응답이 비어 있음")
        }
        guard route.resultCode == 0,
              let mapped = RouteMapper.map(route, origin: origin, destination: destination)
        else {
            throw DomainError.routeNotFound(reason: route.resultMsg)
        }
        return mapped
    }
}
