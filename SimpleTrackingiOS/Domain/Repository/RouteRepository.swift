import Foundation

protocol RouteRepository: Sendable {
    /// 자동차 경로.
    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route
    func findWalkingRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route
    /// 대중교통 경로 후보들. 빠른 순서는 보장하지 않는다.
    func findTransitRoutes(from origin: GeoPoint, to destination: GeoPoint) async throws -> [TransitRoute]
}
