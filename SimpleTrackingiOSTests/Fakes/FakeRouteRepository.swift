import Foundation
@testable import SimpleTrackingiOS

actor FakeRouteRepository: RouteRepository {
    private(set) var callCount = 0
    private let result: Route

    init(result: Route = Route(points: [], distanceMeters: 0, durationSeconds: 0)) {
        self.result = result
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> Route {
        callCount += 1
        return result
    }
}
