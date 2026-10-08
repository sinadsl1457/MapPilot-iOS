import Testing
@testable import SimpleTrackingiOS

struct FixedLocationRepositoryTests {
    private let repository = FixedLocationRepository(point: Fixtures.cityHall)

    @Test func isAlwaysAuthorized() async {
        #expect(await repository.permission() == .authorized)
        #expect(await repository.requestPermission() == .authorized)
    }

    @Test func emitsFixedPointImmediately() async throws {
        #expect(await repository.lastKnownLocation()?.point == Fixtures.cityHall)

        var iterator = await repository.locationUpdates().makeAsyncIterator()
        let first = try await iterator.next()
        #expect(first?.point == Fixtures.cityHall)
        #expect(first?.bearing == nil)
    }

    @Test func observeUseCaseShowsFixedLocation() async throws {
        // 정확도 필터(50m)를 통과하는지까지 확인한다.
        var iterator = ObserveLocationUseCase(repository: repository)().makeAsyncIterator()
        #expect(try await iterator.next()?.point == Fixtures.cityHall)
    }
}
