import Testing
@testable import MapPilot

struct FindRouteUseCaseTests {
    @Test func closerThan20mThrowsWithoutCallingRepository() async {
        let repository = FakeRouteRepository()
        let useCase = FindRouteUseCase(repository: repository)
        // 위도 0.0001도 ≈ 11m
        let nearby = GeoPoint(latitude: Fixtures.cityHall.latitude + 0.0001, longitude: Fixtures.cityHall.longitude)

        await #expect(throws: DomainError.destinationTooClose) {
            try await useCase(from: Fixtures.cityHall, to: nearby)
        }
        #expect(await repository.callCount == 0)
    }

    @Test func farEnoughCallsRepository() async throws {
        let expected = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 9_000, durationSeconds: 1_200)
        let repository = FakeRouteRepository(result: expected)
        let useCase = FindRouteUseCase(repository: repository)

        let route = try await useCase(from: Fixtures.cityHall, to: Fixtures.gangnamStation)

        #expect(route == expected)
        #expect(await repository.callCount == 1)
    }
}
