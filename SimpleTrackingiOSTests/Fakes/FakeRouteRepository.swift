import Foundation
@testable import SimpleTrackingiOS

actor FakeRouteRepository: RouteRepository {
    private(set) var callCount = 0
    private(set) var walkCallCount = 0
    private(set) var transitCallCount = 0
    private let result: Result<Route, DomainError>
    private let walkResult: Result<Route, DomainError>
    private let transitResult: Result<[TransitRoute], DomainError>

    init(
        result: Route = Route(points: [], distanceMeters: 0, durationSeconds: 0),
        failure: DomainError? = nil,
        walk: Result<Route, DomainError>? = nil,
        transit: Result<[TransitRoute], DomainError> = .success([])
    ) {
        self.result = failure.map { .failure($0) } ?? .success(result)
        self.walkResult = walk ?? .success(result)
        self.transitResult = transit
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        callCount += 1
        return try result.get()
    }

    func findWalkingRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        walkCallCount += 1
        return try walkResult.get()
    }

    func findTransitRoutes(from origin: GeoPoint, to destination: GeoPoint) async throws -> [TransitRoute] {
        transitCallCount += 1
        return try transitResult.get()
    }
}
