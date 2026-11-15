import Foundation
@testable import MapPilot

actor FakeRouteRepository: RouteRepository {
    private(set) var callCount = 0
    private(set) var walkCallCount = 0
    private(set) var transitCallCount = 0
    /// 자동차 경로 요청의 (출발, 도착). 출발지·도착지를 바꾼 뒤 무엇으로 찾았는지 확인할 때 쓴다.
    private(set) var carRequests: [(origin: GeoPoint, destination: GeoPoint)] = []
    private let delay: Duration?
    private let result: Result<Route, DomainError>
    private let walkResult: Result<Route, DomainError>
    private let transitResult: Result<[TransitRoute], DomainError>

    init(
        result: Route = Route(points: [], distanceMeters: 0, durationSeconds: 0),
        failure: DomainError? = nil,
        walk: Result<Route, DomainError>? = nil,
        transit: Result<[TransitRoute], DomainError> = .success([]),
        delay: Duration? = nil
    ) {
        self.delay = delay
        self.result = failure.map { .failure($0) } ?? .success(result)
        self.walkResult = walk ?? .success(result)
        self.transitResult = transit
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        callCount += 1
        carRequests.append((origin, destination))
        if let delay { try? await Task.sleep(for: delay) }
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
