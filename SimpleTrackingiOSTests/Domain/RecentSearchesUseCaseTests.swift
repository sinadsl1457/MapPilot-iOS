import Testing
@testable import SimpleTrackingiOS

struct RecentSearchesUseCaseTests {
    @Test func addPutsNewestFirst() async {
        let useCase = RecentSearchesUseCase(repository: FakeRecentSearchRepository(["카페"]))

        let result = await useCase.add("편의점")

        #expect(result == ["편의점", "카페"])
    }

    @Test func addMovesDuplicateToFront() async {
        let useCase = RecentSearchesUseCase(repository: FakeRecentSearchRepository(["a", "b", "c"]))

        let result = await useCase.add("c")

        #expect(result == ["c", "a", "b"])
    }

    @Test func addNormalizesWhitespaceAndIgnoresBlank() async {
        let repository = FakeRecentSearchRepository(["카페"])
        let useCase = RecentSearchesUseCase(repository: repository)

        #expect(await useCase.add("  강남   역 ") == ["강남 역", "카페"])
        #expect(await useCase.add("   ") == ["강남 역", "카페"])
    }

    @Test func keepsAtMost10() async {
        let existing = (1...10).map { "q\($0)" }
        let useCase = RecentSearchesUseCase(repository: FakeRecentSearchRepository(existing))

        let result = await useCase.add("new")

        #expect(result.count == 10)
        #expect(result.first == "new")
        #expect(!result.contains("q10"))
    }

    @Test func removeAndClear() async {
        let repository = FakeRecentSearchRepository(["a", "b"])
        let useCase = RecentSearchesUseCase(repository: repository)

        #expect(await useCase.remove("a") == ["b"])
        await useCase.clear()
        #expect(await useCase.list().isEmpty)
    }
}
