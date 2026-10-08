import Foundation
@testable import SimpleTrackingiOS

actor FakeRouteRepository: RouteRepository {
    private(set) var callCount = 0
    private let result: Route
    private let failure: (any Error)?

    init(result: Route = Route(points: [], distanceMeters: 0, durationSeconds: 0), failure: (any Error)? = nil) {
        self.result = result
        self.failure = failure
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        callCount += 1
        if let failure { throw failure }
        return result
    }
}
