import Foundation
import Testing
@testable import MapPilot

/// Flutter endpoint_search_notifier_test와 같은 경우.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct EndpointSearchViewModelTests {
    private let cafes = [Fixtures.place(id: "c1"), Fixtures.place(id: "c2")]
    private let banks = [Fixtures.place(id: "b1")]

    private func makeViewModel(
        _ places: some PlaceRepository,
        recents: FakeRecentSearchRepository = FakeRecentSearchRepository(),
        recentPlaces: FakeRecentPlaceRepository = FakeRecentPlaceRepository(),
        delay: Duration = .zero
    ) -> EndpointSearchViewModel {
        EndpointSearchViewModel(
            searchPlaces: SearchPlacesUseCase(repository: places),
            recentSearches: RecentSearchesUseCase(repository: recents),
            recentPlaces: RecentPlacesUseCase(repository: recentPlaces),
            searchDelay: delay
        )
    }

    @Test func submitShowsResultsAndAddsRecentQuery() async {
        let recents = FakeRecentSearchRepository()
        let viewModel = makeViewModel(FakePlaceRepository(result: cafes), recents: recents)
        viewModel.query = " 카페 "

        await viewModel.submit(center: nil)

        #expect(viewModel.results == cafes)
        #expect(viewModel.resultsQuery == "카페")
        #expect(viewModel.recentQueries == ["카페"])
        #expect(await recents.stored == ["카페"])
    }

    @Test func emptyQueryShowsErrorAndKeepsResults() async {
        let viewModel = makeViewModel(FakePlaceRepository(result: cafes))
        var errors = viewModel.errors.makeAsyncIterator()

        await viewModel.submit(center: nil)

        #expect(await errors.next() == .emptyQuery)
        #expect(viewModel.results == nil)
        #expect(viewModel.isSubmitting == false)
    }

    @Test func clearingInputGoesBackToRecents() async {
        let viewModel = makeViewModel(FakePlaceRepository(result: cafes))
        viewModel.query = "카페"
        await viewModel.submit(center: nil)

        viewModel.onQueryChanged("", center: nil)

        #expect(viewModel.results == nil)
    }

    @Test func searchesRecentAgain() async {
        let repository = FakePlaceRepository(result: cafes)
        let viewModel = makeViewModel(repository)

        await viewModel.searchRecent("카페", center: nil)

        #expect(viewModel.query == "카페")
        #expect(viewModel.results == cafes)
        #expect(await repository.receivedQueries == ["카페"])
    }

    // MARK: - 실시간 검색

    @Test func showsListWhenTypingPausesWithoutEnter() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))

        viewModel.onQueryChanged("카페", center: nil)
        #expect(await repository.receivedQueries.isEmpty)
        await viewModel.waitForSearch()

        #expect(viewModel.results == cafes)
        #expect(viewModel.resultsQuery == "카페")
    }

    @Test func rapidTypingSearchesOnlyLastInput() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))

        viewModel.onQueryChanged("카", center: nil)
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSearch()

        #expect(await repository.receivedQueries == ["카페"])
    }

    @Test func keepsPreviousListUntilNewResultsArrive() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes, "은행": banks])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSearch()

        viewModel.onQueryChanged("은행", center: nil)
        #expect(viewModel.results == cafes)
        await viewModel.waitForSearch()

        #expect(viewModel.results == banks)
    }

    @Test func clearingInputCancelsPendingRequest() async throws {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))

        viewModel.onQueryChanged("카페", center: nil)
        viewModel.onQueryChanged("", center: nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(await repository.receivedQueries.isEmpty)
        #expect(viewModel.results == nil)
    }

    @Test func failureWhileTypingShowsNoError() async throws {
        let viewModel = makeViewModel(FakePlaceRepository(failure: DomainError.network))
        var errors = viewModel.errors.makeAsyncIterator()

        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSearch()
        // 엔터 검색의 오류가 첫 오류여야 한다(실시간 검색 오류는 나오지 않음).
        viewModel.query = ""
        await viewModel.submit(center: nil)

        #expect(await errors.next() == .emptyQuery)
        #expect(viewModel.results == nil)
    }

    @Test func pickingFromListRemembersPlaceAndItsQuery() async {
        let recents = FakeRecentSearchRepository()
        let recentPlaces = FakeRecentPlaceRepository()
        let viewModel = makeViewModel(ScriptedPlaceRepository(results: ["카페": cafes]), recents: recents, recentPlaces: recentPlaces)
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSearch()

        await viewModel.remember(cafes[0])

        #expect(await recents.stored == ["카페"])
        #expect(await recentPlaces.stored.map(\.place.id) == ["c1"])
    }
}
