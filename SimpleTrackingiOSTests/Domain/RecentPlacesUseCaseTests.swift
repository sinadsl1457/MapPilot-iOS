import Foundation
import Testing
@testable import SimpleTrackingiOS

struct RecentPlacesUseCaseTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func newestFirstAndSamePlaceOnlyOnce() async {
        let repository = FakeRecentPlaceRepository()
        let useCase = RecentPlacesUseCase(repository: repository)
        let a = Fixtures.place(id: "a"), b = Fixtures.place(id: "b")

        await useCase.add(a, now: now)
        await useCase.add(b, now: now.addingTimeInterval(1))
        let places = await useCase.add(a, now: now.addingTimeInterval(2))

        #expect(places.map(\.place.id) == ["a", "b"])
        #expect(places.first?.usedAt == now.addingTimeInterval(2))
        #expect(await repository.stored == places)
    }

    @Test func keepsAtMostMaxCount() async {
        let useCase = RecentPlacesUseCase(repository: FakeRecentPlaceRepository())

        var places: [RecentPlace] = []
        for index in 0...RecentPlacesUseCase.maxCount {
            places = await useCase.add(Fixtures.place(id: "\(index)"), now: now)
        }

        #expect(places.count == RecentPlacesUseCase.maxCount)
        #expect(places.first?.place.id == "\(RecentPlacesUseCase.maxCount)")
        #expect(places.contains { $0.place.id == "0" } == false)
    }

    @Test func removeDropsOnlyThatPlace() async {
        let useCase = RecentPlacesUseCase(repository: FakeRecentPlaceRepository([
            RecentPlace(place: Fixtures.place(id: "a"), usedAt: now),
            RecentPlace(place: Fixtures.place(id: "b"), usedAt: now),
        ]))

        let places = await useCase.remove(placeID: "a")

        #expect(places.map(\.place.id) == ["b"])
    }
}
