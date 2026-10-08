import Testing
@testable import SimpleTrackingiOS

struct RoutingUseCaseTests {
    private let nearby = GeoPoint(latitude: Fixtures.cityHall.latitude + 0.0001, longitude: Fixtures.cityHall.longitude)

    @Test func walkingTooCloseDoesNotCallApi() async {
        let repository = FakeRouteRepository()
        await #expect(throws: DomainError.destinationTooClose) {
            try await FindWalkingRouteUseCase(repository: repository)(from: Fixtures.cityHall, to: nearby)
        }
        #expect(await repository.walkCallCount == 0)
    }

    @Test func transitTooCloseDoesNotCallApi() async {
        let repository = FakeRouteRepository()
        await #expect(throws: DomainError.destinationTooClose) {
            try await FindTransitRoutesUseCase(repository: repository)(from: Fixtures.cityHall, to: nearby)
        }
        #expect(await repository.transitCallCount == 0)
    }

    @Test func transitSortsFastestFirst() async throws {
        let repository = FakeRouteRepository(transit: .success([
            Fixtures.transitRoute(minutes: 70),
            Fixtures.transitRoute(minutes: 55),
            Fixtures.transitRoute(minutes: 62),
        ]))

        let routes = try await FindTransitRoutesUseCase(repository: repository)(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        #expect(routes.map(\.durationSeconds) == [55 * 60, 62 * 60, 70 * 60])
    }

    @Test func emptyTransitIsRouteNotFound() async {
        let repository = FakeRouteRepository(transit: .success([]))
        await #expect(throws: DomainError.routeNotFound(reason: "대중교통 경로 없음")) {
            try await FindTransitRoutesUseCase(repository: repository)(from: Fixtures.cityHall, to: Fixtures.gangnamStation)
        }
    }
}
