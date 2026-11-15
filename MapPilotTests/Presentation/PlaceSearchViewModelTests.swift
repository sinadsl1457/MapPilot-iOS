import Testing
@testable import MapPilot

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PlaceSearchViewModelTests {
    private let places = [
        Fixtures.place(id: "1", latitude: 37.50),
        Fixtures.place(id: "2", latitude: 37.51),
    ]

    private func makeViewModel(
        places: FakePlaceRepository,
        recents: FakeRecentSearchRepository = FakeRecentSearchRepository(),
        recentPlaces: FakeRecentPlaceRepository = FakeRecentPlaceRepository()
    ) -> PlaceSearchViewModel {
        PlaceSearchViewModel(
            searchPlaces: SearchPlacesUseCase(repository: places),
            searchPlacesByCategory: SearchPlacesByCategoryUseCase(repository: places),
            recentSearches: RecentSearchesUseCase(repository: recents),
            recentPlaces: RecentPlacesUseCase(repository: recentPlaces)
        )
    }

    @Test func selectedPlaceIsKeptInRecentPlaces() async throws {
        let recentPlaces = FakeRecentPlaceRepository()
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places), recentPlaces: recentPlaces)

        viewModel.select(places[1])
        // 기록은 화면을 막지 않게 뒤에서 한다.
        while await recentPlaces.stored.isEmpty { try await Task.sleep(for: .milliseconds(10)) }

        #expect(await recentPlaces.stored.map(\.place.id) == ["2"])
    }

    // MARK: - 키워드

    @Test func submitShowsResultsClosesPageAndFitsCamera() async {
        let recents = FakeRecentSearchRepository()
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places), recents: recents)
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.openSearchPage()
        viewModel.query = "  강남  카페 "

        await viewModel.submit(center: Fixtures.cityHall)

        #expect(viewModel.isSearchPagePresented == false)
        #expect(viewModel.source == .keyword("강남 카페"))
        #expect(viewModel.places == places)
        #expect(viewModel.recentQueries == ["강남 카페"])
        #expect(await recents.stored == ["강남 카페"])
        #expect(await effects.next() == .fitCamera(places.map(\.location)))
    }

    @Test func blankSubmitStaysOnPageAndShowsError() async {
        let repository = FakePlaceRepository(result: places)
        let viewModel = makeViewModel(places: repository)
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.openSearchPage()
        viewModel.query = "   "

        await viewModel.submit(center: nil)

        #expect(viewModel.isSearchPagePresented)
        #expect(viewModel.source == nil)
        #expect(await effects.next() == .showError(.emptyQuery))
        #expect(await repository.receivedQueries.isEmpty)
    }

    @Test func networkErrorStaysOnPage() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(failure: DomainError.network))
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.openSearchPage()
        viewModel.query = "카페"

        await viewModel.submit(center: nil)

        #expect(viewModel.isSearchPagePresented)
        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.recentQueries.isEmpty)
        #expect(await effects.next() == .showError(.network))
    }

    @Test func emptyResultsShowSheetWithoutMovingCamera() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: []))
        viewModel.query = "없는장소"

        await viewModel.submit(center: nil)

        #expect(viewModel.source == .keyword("없는장소"))
        #expect(viewModel.phase == .loaded([]))
    }

    @Test func recentSearchRunsAgain() async {
        let repository = FakePlaceRepository(result: places)
        let viewModel = makeViewModel(places: repository, recents: FakeRecentSearchRepository(["카페", "약국"]))
        await viewModel.onAppear()

        await viewModel.searchRecent("약국", center: nil)

        #expect(await repository.receivedQueries == ["약국"])
        #expect(viewModel.recentQueries == ["약국", "카페"])
    }

    @Test func openingPageRestoresCurrentKeyword() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        viewModel.query = "카페"
        await viewModel.submit(center: nil)
        viewModel.query = "다른 입력"

        viewModel.openSearchPage()

        #expect(viewModel.query == "카페")
    }

    // MARK: - 카테고리

    @Test func categoryShowsResultsAroundCenter() async {
        let repository = FakePlaceRepository(result: places)
        let viewModel = makeViewModel(places: repository)
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)

        #expect(viewModel.selectedCategory == .cafe)
        #expect(viewModel.places == places)
        #expect(await repository.receivedCategories.first?.center == Fixtures.cityHall)
        #expect(await effects.next() == .fitCamera(places.map(\.location)))
    }

    @Test func tappingSameCategoryClearsResults() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)

        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)

        #expect(viewModel.source == nil)
        #expect(viewModel.places.isEmpty)
    }

    @Test func categoryErrorClearsAndShowsError() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(failure: DomainError.quotaExceeded))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.toggleCategory(.pharmacy, around: Fixtures.cityHall)

        #expect(viewModel.source == nil)
        #expect(await effects.next() == .showError(.quotaExceeded))
    }

    // MARK: - 선택

    @Test func selectingFocusesPlace() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        var effects = viewModel.effects.makeAsyncIterator()
        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)
        _ = await effects.next() // fitCamera

        viewModel.selectPlace(id: "2")

        #expect(viewModel.selectedPlace == places[1])
        #expect(await effects.next() == .focus(places[1].location))
    }

    @Test func unknownMarkerIdIsIgnored() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)

        viewModel.selectPlace(id: "없음")

        #expect(viewModel.selectedPlace == nil)
    }

    @Test func newSearchClearsSelection() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        await viewModel.toggleCategory(.cafe, around: Fixtures.cityHall)
        viewModel.select(places[0])

        await viewModel.toggleCategory(.pharmacy, around: Fixtures.cityHall)

        #expect(viewModel.selectedPlace == nil)
        #expect(viewModel.selectedCategory == .pharmacy)
    }

    @Test func clearResultsResetsEverything() async {
        let viewModel = makeViewModel(places: FakePlaceRepository(result: places))
        viewModel.query = "카페"
        await viewModel.submit(center: nil)
        viewModel.select(places[0])

        viewModel.clearResults()

        #expect(viewModel.source == nil)
        #expect(viewModel.phase == nil)
        #expect(viewModel.selectedPlace == nil)
        #expect(viewModel.query.isEmpty)
    }
}

// MARK: - 실시간 검색 (Flutter place_search_notifier_test '실시간 검색'과 같은 경우)

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PlaceSearchSuggestionTests {
    private let cafes = [Fixtures.place(id: "c1", latitude: 37.50), Fixtures.place(id: "c2", latitude: 37.51)]
    private let banks = [Fixtures.place(id: "b1", latitude: 37.52)]

    private func makeViewModel(
        _ repository: ScriptedPlaceRepository,
        recents: FakeRecentSearchRepository = FakeRecentSearchRepository(),
        delay: Duration = .zero
    ) -> PlaceSearchViewModel {
        PlaceSearchViewModel(
            searchPlaces: SearchPlacesUseCase(repository: repository),
            searchPlacesByCategory: SearchPlacesByCategoryUseCase(repository: repository),
            recentSearches: RecentSearchesUseCase(repository: recents),
            recentPlaces: RecentPlacesUseCase(repository: FakeRecentPlaceRepository()),
            suggestDelay: delay
        )
    }

    @Test func searchesAfterTypingPausesNotBefore() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))

        viewModel.onQueryChanged("카페", center: nil)
        #expect(await repository.receivedQueries.isEmpty)
        #expect(viewModel.isSuggesting)

        await viewModel.waitForSuggestion()

        #expect(await repository.receivedQueries == ["카페"])
        #expect(viewModel.suggestions == cafes)
        #expect(viewModel.suggestionsQuery == "카페")
        #expect(viewModel.isSuggesting == false)
    }

    @Test func rapidTypingSearchesOnlyLastInput() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))

        viewModel.onQueryChanged("카", center: nil)
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()

        #expect(await repository.receivedQueries == ["카페"])
    }

    @Test func discardsLateResultOfPreviousInput() async throws {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes, "은행": banks], delays: ["카페": .milliseconds(300)])
        let viewModel = makeViewModel(repository)

        viewModel.onQueryChanged("카페", center: nil)
        // "카페" 요청이 서버에 도착할 때까지 기다린 뒤 다음 입력
        while await repository.receivedQueries.isEmpty { await Task.yield() }
        viewModel.onQueryChanged("은행", center: nil)
        await viewModel.waitForSuggestion()
        try await Task.sleep(for: .milliseconds(400)) // 늦은 "카페" 응답이 도착할 시간

        #expect(viewModel.suggestions == banks)
        #expect(viewModel.suggestionsQuery == "은행")
    }

    @Test func keepsPreviousResultsWhileNewInputLoads() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes, "은행": banks])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()

        viewModel.onQueryChanged("은행", center: nil)

        #expect(viewModel.suggestions == cafes)
        #expect(viewModel.isSuggesting)
        #expect(viewModel.isSuggestionEmpty == false)
    }

    @Test func pickingWhileTypingKeepsQueryOfThatList() async {
        let recents = FakeRecentSearchRepository()
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, recents: recents, delay: .milliseconds(100))
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()
        viewModel.onQueryChanged("카페 강", center: nil)

        await viewModel.pickSuggestion(cafes[1])

        #expect(viewModel.source == .keyword("카페"))
        #expect(viewModel.recentQueries == ["카페"])
    }

    @Test func whitespaceOnlyChangeDoesNotSearchAgain() async {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository)
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()

        viewModel.onQueryChanged(" 카페  ", center: nil)
        await viewModel.waitForSuggestion()

        #expect(await repository.receivedQueries == ["카페"])
        #expect(viewModel.query == " 카페  ")
    }

    @Test func clearingInputEmptiesSuggestionsAndCancelsPending() async throws {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes, "은행": banks])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()

        viewModel.onQueryChanged("은행", center: nil)
        viewModel.onQueryChanged("", center: nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(await repository.receivedQueries == ["카페"])
        #expect(viewModel.suggestFor.isEmpty)
        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.isSuggesting == false)
    }

    @Test func submitCancelsPendingSuggestion() async throws {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))
        viewModel.openSearchPage()

        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.submit(center: nil)
        try await Task.sleep(for: .milliseconds(200))

        // 엔터 검색 한 번만
        #expect(await repository.receivedQueries == ["카페"])
        #expect(viewModel.places == cafes)
    }

    @Test func pickingSuggestionShowsItOnMapWithoutSearchingAgain() async {
        let recents = FakeRecentSearchRepository()
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, recents: recents)
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.openSearchPage()
        viewModel.onQueryChanged("카페", center: nil)
        await viewModel.waitForSuggestion()

        await viewModel.pickSuggestion(cafes[1])

        #expect(await repository.receivedQueries == ["카페"])
        #expect(viewModel.isSearchPagePresented == false)
        #expect(viewModel.places == cafes)
        #expect(viewModel.selectedPlace == cafes[1])
        #expect(await recents.stored == ["카페"])
        #expect(await effects.next() == .focus(cafes[1].location))
    }

    @Test func closingPageCancelsPendingSuggestion() async throws {
        let repository = ScriptedPlaceRepository(results: ["카페": cafes])
        let viewModel = makeViewModel(repository, delay: .milliseconds(100))
        viewModel.openSearchPage()

        viewModel.onQueryChanged("카페", center: nil)
        viewModel.closeSearchPage()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await repository.receivedQueries.isEmpty)
    }

    @Test func emptyResultOfCurrentInputShowsNoResults() async {
        let repository = ScriptedPlaceRepository(results: [:])
        let viewModel = makeViewModel(repository)

        viewModel.onQueryChanged("없는곳", center: nil)
        #expect(viewModel.isSuggestionEmpty == false) // 아직 받는 중
        await viewModel.waitForSuggestion()

        #expect(viewModel.isSuggestionEmpty)
    }
}
