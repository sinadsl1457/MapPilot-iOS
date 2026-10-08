import Foundation

struct FindWalkingRouteUseCase: Sendable {
    private let repository: any RouteRepository

    init(repository: any RouteRepository) {
        self.repository = repository
    }

    func callAsFunction(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        try FindRouteUseCase.ensureFarEnough(origin, destination)
        return try await repository.findWalkingRoute(from: origin, to: destination)
    }
}
