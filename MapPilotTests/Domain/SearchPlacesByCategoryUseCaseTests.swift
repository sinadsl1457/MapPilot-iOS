import Testing
@testable import MapPilot

struct SearchPlacesByCategoryUseCaseTests {
    @Test func searchesWithin1kmOfCenter() async throws {
        let expected = [Fixtures.place(id: "1")]
        let repository = FakePlaceRepository(result: expected)
        let useCase = SearchPlacesByCategoryUseCase(repository: repository)

        let places = try await useCase(.cafe, around: Fixtures.cityHall)

        #expect(places == expected)
        let call = try #require(await repository.receivedCategories.first)
        #expect(call.category == .cafe)
        #expect(call.center == Fixtures.cityHall)
        #expect(call.radius == 1_000)
    }
}
