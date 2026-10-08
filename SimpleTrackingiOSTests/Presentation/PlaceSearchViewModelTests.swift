import Testing
@testable import SimpleTrackingiOS

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PlaceSearchViewModelTests {
    private let places = [
        Fixtures.place(id: "1", latitude: 37.50),
        Fixtures.place(id: "2", latitude: 37.51),
    ]

    private func makeViewModel(
        places: FakePlaceRepository,
        recents: FakeRecentSearchRepository = FakeRecentSearchRepository()
    ) -> PlaceSearchViewModel {
        PlaceSearchViewModel(
            searchPlaces: SearchPlacesUseCase(repository: places),
            searchPlacesByCategory: SearchPlacesByCategoryUseCase(repository: places),
            recentSearches: RecentSearchesUseCase(repository: recents)
        )
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
