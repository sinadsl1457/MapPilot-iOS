import Foundation

protocol RouteRepository: Sendable {
    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route
}
