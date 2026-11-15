import Foundation
import Observation

/// 길찾기 준비 화면에서 정한 것. 지도 화면이 받아 길찾기를 실행한다(RouteViewModel.plan).
struct RoutePlan: Equatable, Sendable {
    let origin: RouteEndpoint
    let destination: RouteEndpoint
    let mode: TravelMode
}

enum RoutePlannerEffect: Equatable, Sendable {
    /// 출발지·도착지가 모두 정해졌다. 화면은 닫고 plan으로 길찾기를 한다.
    case completed(RoutePlan)
}

/// 지도 첫 화면의 길찾기 버튼으로 여는 준비 화면(RoutePlannerPage) 로직.
/// 출발지(기본: 내 위치)와 도착지를 정하고, 최근 장소를 바로 도착지로 고를 수 있다.
/// 두 지점이 모두 정해지면 effect completed → 페이지가 닫히며 MapScreen이 RouteViewModel.plan을 부른다.
/// 준비 화면이 떠 있는 동안만 산다.
@MainActor
@Observable
final class RoutePlannerViewModel {
    /// 처음에는 내 위치. 맞바꾸면 비어 있을 수 있다.
    private(set) var origin: RouteEndpoint? = .myLocation
    private(set) var destination: RouteEndpoint?
    private(set) var mode: TravelMode
    private(set) var recentPlaces: [RecentPlace] = []

    let effects: AsyncStream<RoutePlannerEffect>

    @ObservationIgnored private let effectContinuation: AsyncStream<RoutePlannerEffect>.Continuation
    @ObservationIgnored private let recentPlacesUseCase: RecentPlacesUseCase

    /// `mode`는 지난 길찾기에서 고른 이동 수단.
    init(mode: TravelMode, recentPlaces: RecentPlacesUseCase) {
        self.mode = mode
        recentPlacesUseCase = recentPlaces
        (effects, effectContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        effectContinuation.finish()
    }

    func onAppear() async {
        recentPlaces = await recentPlacesUseCase.list()
    }

    /// 출발지 줄 탭 → 선택 페이지에서 고른 값. 도착지도 있으면 바로 completed.
    func setOrigin(_ origin: RouteEndpoint) {
        self.origin = origin
        completeIfReady()
    }

    /// 도착지 줄 탭 → 선택 페이지에서 고른 값(또는 chooseRecent). 출발지도 있으면 바로 completed.
    func setDestination(_ destination: RouteEndpoint) {
        self.destination = destination
        completeIfReady()
    }

    /// 출발지와 도착지를 맞바꾼다. 둘 다 정해져 있으면 바로 길찾기로 넘어간다.
    func swap() {
        (origin, destination) = (destination, origin)
        completeIfReady()
    }

    /// 이동 수단 아이콘 탭. 결과 화면의 첫 탭이 된다.
    func selectMode(_ mode: TravelMode) {
        self.mode = mode
    }

    /// 최근 장소를 누르면 도착지로 정한다. 목록에서도 맨 앞으로 올린다.
    func chooseRecent(_ recent: RecentPlace) async {
        setDestination(.place(recent.place))
        await recentPlacesUseCase.add(recent.place)
    }

    /// 최근 장소 줄의 X.
    func removeRecent(_ recent: RecentPlace) async {
        recentPlaces = await recentPlacesUseCase.remove(placeID: recent.place.id)
    }

    private func completeIfReady() {
        guard let origin, let destination else { return }
        effectContinuation.yield(.completed(RoutePlan(origin: origin, destination: destination, mode: mode)))
    }
}
