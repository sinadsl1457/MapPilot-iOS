import Foundation
import Testing
@testable import MapPilot

/// Flutter route_planner_notifier_test와 같은 경우.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RoutePlannerViewModelTests {
    private let recent = RecentPlace(place: Fixtures.place(id: "r"), usedAt: Date(timeIntervalSince1970: 1_800_000_000))

    private func makeViewModel(_ repository: FakeRecentPlaceRepository, mode: TravelMode = .transit) -> RoutePlannerViewModel {
        RoutePlannerViewModel(mode: mode, recentPlaces: RecentPlacesUseCase(repository: repository))
    }

    @Test func startsFromMyLocationWithEmptyDestinationAndLoadsRecents() async {
        let viewModel = makeViewModel(FakeRecentPlaceRepository([recent]), mode: .walk)

        await viewModel.onAppear()

        #expect(viewModel.origin == .myLocation)
        #expect(viewModel.destination == nil)
        #expect(viewModel.mode == .walk)
        #expect(viewModel.recentPlaces == [recent])
    }

    @Test func choosingRecentSetsDestinationAndCompletes() async {
        let repository = FakeRecentPlaceRepository([recent])
        let viewModel = makeViewModel(repository)
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.selectMode(.car)

        await viewModel.chooseRecent(recent)

        #expect(await effects.next() == .completed(RoutePlan(origin: .myLocation, destination: .place(recent.place), mode: .car)))
        // 다시 고른 장소는 목록 맨 앞으로(고른 시각 갱신)
        #expect(await repository.stored.first?.place.id == "r")
        #expect(await repository.stored.first?.usedAt != recent.usedAt)
    }

    @Test func swappingWithEmptyDestinationEmptiesOriginAndWaits() async {
        let viewModel = makeViewModel(FakeRecentPlaceRepository())

        viewModel.swap()

        #expect(viewModel.origin == nil)
        #expect(viewModel.destination == .myLocation)
    }

    @Test func fillingEmptyOriginCompletes() async {
        let viewModel = makeViewModel(FakeRecentPlaceRepository())
        var effects = viewModel.effects.makeAsyncIterator()
        viewModel.swap()

        viewModel.setOrigin(.place(recent.place))

        #expect(await effects.next() == .completed(RoutePlan(origin: .place(recent.place), destination: .myLocation, mode: .transit)))
    }

    @Test func removingRecent() async {
        let repository = FakeRecentPlaceRepository([recent])
        let viewModel = makeViewModel(repository)
        await viewModel.onAppear()

        await viewModel.removeRecent(recent)

        #expect(viewModel.recentPlaces.isEmpty)
        #expect(await repository.stored.isEmpty)
    }
}
