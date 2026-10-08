import Foundation

/// 자동차 경로.
struct FindRouteUseCase: Sendable {
    static let minimumDistanceMeters = 20.0

    private let repository: any RouteRepository

    init(repository: any RouteRepository) {
        self.repository = repository
    }

    func callAsFunction(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        try Self.ensureFarEnough(origin, destination)
        return try await repository.findRoute(from: origin, to: destination)
    }

    /// 출발지와 도착지가 너무 가까우면 API를 부르지 않는다. 모든 이동 수단에 같이 적용한다.
    static func ensureFarEnough(_ origin: GeoPoint, _ destination: GeoPoint) throws {
        guard GeoMath.distanceMeters(origin, destination) >= minimumDistanceMeters else {
            throw DomainError.destinationTooClose
        }
    }
}
