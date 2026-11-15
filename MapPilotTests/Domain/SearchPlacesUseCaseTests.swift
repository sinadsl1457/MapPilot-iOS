import Testing
@testable import MapPilot

struct SearchPlacesUseCaseTests {
    @Test(arguments: [
        ("  강남역  ", "강남역"),
        ("강남   맛집", "강남 맛집"),
        ("\t서울\n시청 ", "서울 시청"),
    ])
    func normalizesWhitespace(input: String, expected: String) async throws {
        let repository = FakePlaceRepository()
        let useCase = SearchPlacesUseCase(repository: repository)

        _ = try await useCase(query: input)

        #expect(await repository.receivedQueries == [expected])
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func blankQueryThrowsWithoutCallingRepository(input: String) async {
        let repository = FakePlaceRepository()
        let useCase = SearchPlacesUseCase(repository: repository)

        await #expect(throws: DomainError.emptyQuery) {
            try await useCase(query: input)
        }
        #expect(await repository.receivedQueries.isEmpty)
    }
}
