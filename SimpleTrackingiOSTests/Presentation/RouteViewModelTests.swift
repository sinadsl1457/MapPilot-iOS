import Testing
@testable import SimpleTrackingiOS

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RouteViewModelTests {
    private let destination = Fixtures.place(id: "dest", latitude: Fixtures.gangnamStation.latitude, longitude: Fixtures.gangnamStation.longitude)
    private let route = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 9_120, durationSeconds: 1_500)

    private func makeViewModel(_ repository: FakeRouteRepository) -> RouteViewModel {
        RouteViewModel(findRoute: FindRouteUseCase(repository: repository))
    }

    @Test func successShowsRouteAndFitsCamera() async {
        let viewModel = makeViewModel(FakeRouteRepository(result: route))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        #expect(viewModel.isActive)
        #expect(viewModel.destination == destination)
        #expect(viewModel.phase == .loaded(route))
        #expect(await effects.next() == .fitCamera(route.points))
    }

    @Test func withoutOriginShowsMessageAndDoesNotCallApi() async {
        let repository = FakeRouteRepository(result: route)
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, from: nil)

        #expect(viewModel.isActive == false)
        guard case .showMessage = await effects.next() else {
            Issue.record("showMessage를 기대함")
            return
        }
        #expect(await repository.callCount == 0)
    }

    @Test func tooCloseExitsWithError() async {
        let repository = FakeRouteRepository(result: route)
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()
        let nearby = Fixtures.place(id: "near", latitude: Fixtures.cityHall.latitude, longitude: Fixtures.cityHall.longitude)

        await viewModel.start(to: nearby, from: Fixtures.cityHall)

        #expect(viewModel.isActive == false)
        #expect(await effects.next() == .showError(.destinationTooClose))
        #expect(await repository.callCount == 0)
    }

    @Test func routeNotFoundExitsWithError() async {
        let viewModel = makeViewModel(FakeRouteRepository(failure: DomainError.routeNotFound(reason: "없음")))
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        #expect(viewModel.isActive == false)
        #expect(viewModel.phase == nil)
        #expect(await effects.next() == .showError(.routeNotFound(reason: "없음")))
    }

    @Test func closeClearsState() async {
        let viewModel = makeViewModel(FakeRouteRepository(result: route))
        await viewModel.start(to: destination, from: Fixtures.cityHall)

        viewModel.close()

        #expect(viewModel.isActive == false)
        #expect(viewModel.route == nil)
    }
}
