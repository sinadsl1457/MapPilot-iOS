import Testing
@testable import SimpleTrackingiOS

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RouteViewModelTests {
    private let destination = Fixtures.place(id: "dest", latitude: Fixtures.gangnamStation.latitude, longitude: Fixtures.gangnamStation.longitude)
    private let carRoute = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 9_120, durationSeconds: 1_500)
    private let walkRoute = Route(points: [Fixtures.cityHall, Fixtures.gangnamStation], distanceMeters: 8_900, durationSeconds: 8_000)
    private let stationA = GeoPoint(latitude: 37.56, longitude: 126.98)
    private let stationB = GeoPoint(latitude: 37.50, longitude: 127.02)

    private var transitRoutes: [TransitRoute] {
        [
            Fixtures.transitRoute(minutes: 40, legs: [
                TransitLeg(kind: .subway, durationSeconds: 2_000, distanceMeters: 8_000, guidance: "2호선", lineNames: ["2호선"], stops: ["시청", "강남"], points: [stationA, stationB]),
            ]),
            Fixtures.transitRoute(minutes: 50),
        ]
    }

    private func makeViewModel(_ repository: FakeRouteRepository) -> RouteViewModel {
        RouteViewModel(
            findCarRoute: FindRouteUseCase(repository: repository),
            findWalkingRoute: FindWalkingRouteUseCase(repository: repository),
            findTransitRoutes: FindTransitRoutesUseCase(repository: repository)
        )
    }

    private func defaultRepository() -> FakeRouteRepository {
        FakeRouteRepository(result: carRoute, walk: .success(walkRoute), transit: .success(transitRoutes))
    }

    @Test func startFetchesAllModes() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        #expect(viewModel.isActive)
        #expect(viewModel.results[.car] == .route(carRoute))
        #expect(viewModel.results[.walk] == .route(walkRoute))
        #expect(viewModel.results[.transit] == .transit(transitRoutes))
        #expect(await repository.callCount == 1)
        #expect(await repository.walkCallCount == 1)
        #expect(await repository.transitCallCount == 1)
    }

    @Test func defaultsToTransitAndFitsItsRoute() async {
        let viewModel = makeViewModel(defaultRepository())
        var effects = viewModel.effects.makeAsyncIterator()

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        #expect(viewModel.selectedMode == .transit)
        guard case let .fitCamera(points) = await effects.next() else {
            Issue.record("fitCamera를 기대함")
            return
        }
        #expect(points.contains(stationA))
    }

    @Test func transitOverlayConnectsOriginAndDestinationWithWalkLines() async throws {
        let viewModel = makeViewModel(defaultRepository())

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        let overlay = try #require(viewModel.overlay)
        #expect(overlay.lines.map(\.kind) == [.walk, .subway, .walk])
        #expect(overlay.lines.first?.points == [Fixtures.cityHall, stationA])
        #expect(overlay.lines.last?.points == [stationB, Fixtures.gangnamStation])
        #expect(overlay.start == Fixtures.cityHall)
        #expect(overlay.end == Fixtures.gangnamStation)
    }

    @Test func switchingModeChangesOverlayAndFitsCamera() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, from: Fixtures.cityHall)
        var effects = viewModel.effects.makeAsyncIterator()
        _ = await effects.next() // 대중교통 결과

        viewModel.selectMode(.walk)

        #expect(viewModel.overlay?.lines == [RouteLine(kind: .walk, points: walkRoute.points)])
        #expect(await effects.next() == .fitCamera(viewModel.overlay?.allPoints ?? []))
    }

    @Test func selectingTransitAlternativeChangesOverlay() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, from: Fixtures.cityHall)

        viewModel.selectTransitRoute(at: 1)

        #expect(viewModel.selectedTransitRoute == transitRoutes[1])
    }

    @Test func oneModeFailingKeepsOthers() async {
        let repository = FakeRouteRepository(result: carRoute, walk: .failure(.routeNotFound(reason: "TOO_FAR_AWAY")), transit: .success(transitRoutes))
        let viewModel = makeViewModel(repository)

        await viewModel.start(to: destination, from: Fixtures.cityHall)

        #expect(viewModel.isActive)
        #expect(viewModel.results[.walk] == .failed(.routeNotFound(reason: "TOO_FAR_AWAY")))
        #expect(viewModel.results[.car] == .route(carRoute))
        viewModel.selectMode(.walk)
        #expect(viewModel.overlay == nil)
    }

    @Test func withoutOriginShowsMessageAndDoesNotCallApi() async {
        let repository = defaultRepository()
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

    @Test func tooCloseDoesNotOpenRouteMode() async {
        let repository = defaultRepository()
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()
        let nearby = Fixtures.place(id: "near", latitude: Fixtures.cityHall.latitude, longitude: Fixtures.cityHall.longitude)

        await viewModel.start(to: nearby, from: Fixtures.cityHall)

        #expect(viewModel.isActive == false)
        #expect(await effects.next() == .showError(.destinationTooClose))
        #expect(await repository.callCount == 0)
        #expect(await repository.transitCallCount == 0)
    }

    @Test func closeClearsStateButKeepsSelectedMode() async {
        let viewModel = makeViewModel(defaultRepository())
        await viewModel.start(to: destination, from: Fixtures.cityHall)
        viewModel.selectMode(.car)

        viewModel.close()

        #expect(viewModel.isActive == false)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.overlay == nil)
        #expect(viewModel.selectedMode == .car)
    }
}
