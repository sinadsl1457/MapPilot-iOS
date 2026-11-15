import Testing
@testable import MapPilot

struct ObserveLocationUseCaseTests {
    @Test func emitsLastKnownLocationFirst() async throws {
        let last = Fixtures.location(latitude: 1)
        let live = Fixtures.location(latitude: 2)
        let useCase = ObserveLocationUseCase(repository: FakeLocationRepository(lastKnown: last, updates: [live]))

        let emitted = try await collect(useCase())

        #expect(emitted == [last, live])
    }

    @Test func filtersOutLocationsWorseThan50m() async throws {
        let inaccurateLast = Fixtures.location(latitude: 0, accuracy: 120)
        let good = Fixtures.location(latitude: 1, accuracy: 50)
        let bad = Fixtures.location(latitude: 2, accuracy: 50.1)
        let invalid = Fixtures.location(latitude: 3, accuracy: .greatestFiniteMagnitude)
        let useCase = ObserveLocationUseCase(
            repository: FakeLocationRepository(lastKnown: inaccurateLast, updates: [good, bad, invalid])
        )

        let emitted = try await collect(useCase())

        #expect(emitted == [good])
    }

    @Test func propagatesStreamError() async {
        let useCase = ObserveLocationUseCase(
            repository: FakeLocationRepository(failure: DomainError.locationPermissionDenied)
        )

        await #expect(throws: DomainError.locationPermissionDenied) {
            try await collect(useCase())
        }
    }

    private func collect(_ stream: AsyncThrowingStream<UserLocation, any Error>) async throws -> [UserLocation] {
        var result: [UserLocation] = []
        for try await location in stream {
            result.append(location)
        }
        return result
    }
}
