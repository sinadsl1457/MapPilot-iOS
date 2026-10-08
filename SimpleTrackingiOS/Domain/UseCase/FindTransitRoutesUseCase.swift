import Foundation

struct FindTransitRoutesUseCase: Sendable {
    private let repository: any RouteRepository

    init(repository: any RouteRepository) {
        self.repository = repository
    }

    /// 빠른 순으로 정렬해 돌려준다. 결과가 없으면 `.routeNotFound`.
    func callAsFunction(from origin: GeoPoint, to destination: GeoPoint) async throws -> [TransitRoute] {
        try FindRouteUseCase.ensureFarEnough(origin, destination)
        let routes = try await repository.findTransitRoutes(from: origin, to: destination)
        guard !routes.isEmpty else { throw DomainError.routeNotFound(reason: "대중교통 경로 없음") }
        return routes.sorted { $0.durationSeconds < $1.durationSeconds }
    }
}
