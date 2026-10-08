import Foundation

struct FindRouteUseCase: Sendable {
    static let minimumDistanceMeters = 20.0

    private let repository: any RouteRepository

    init(repository: any RouteRepository) {
        self.repository = repository
    }

    func callAsFunction(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        guard GeoMath.distanceMeters(origin, destination) >= Self.minimumDistanceMeters else {
            throw DomainError.destinationTooClose
        }
        return try await repository.findRoute(from: origin, to: destination)
    }
}
