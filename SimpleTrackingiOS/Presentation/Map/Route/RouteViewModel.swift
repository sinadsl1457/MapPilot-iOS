import Foundation
import Observation

enum RouteEffect: Equatable, Sendable {
    /// 경로 전체가 보이도록 카메라를 맞춘다.
    case fitCamera([GeoPoint])
    case showError(DomainError)
    case showMessage(String)
}

/// 길찾기 결과. 출발지·도착지(RouteEndpoint) → 좌표 결정 → 세 이동 수단 동시 조회 → 목록 → 고른 경로만 지도 선.
/// 진입: start(장소 상세 "길찾기") · plan(길찾기 준비 화면) / 변경: changeOrigin · changeDestination · swap
/// 대중교통은 후보가 여럿이라 목록(RouteListPage)에서 고른 뒤 지도에 그린다(showRoute / backToList).
/// 자동차·도보는 경로가 하나라 그 탭을 고르면 바로 지도에 그린다(selectMode).
/// 화면: RouteListPage(목록), MapScreen(고른 경로). 둘이 이 ViewModel 하나를 같이 본다.
@MainActor
@Observable
final class RouteViewModel {
    enum ModeResult: Equatable {
        case loading
        case route(Route)
        case transit([TransitRoute])
        case failed(DomainError)
    }

    private(set) var origin: RouteEndpoint?
    private(set) var destination: RouteEndpoint?
    /// 조회에 쓴 실제 좌표. 내 위치는 조회를 시작한 순간의 좌표다.
    private(set) var originPoint: GeoPoint?
    private(set) var destinationPoint: GeoPoint?
    /// 마지막으로 고른 이동 수단을 다음 길찾기에서도 유지한다.
    private(set) var selectedMode: TravelMode = .transit
    private(set) var results: [TravelMode: ModeResult] = [:]
    private(set) var selectedTransitIndex = 0
    /// 지도에 경로를 보여 주는 중. false면 대중교통 경로 목록 단계(지도에 선 없음).
    /// 자동차·도보는 고를 후보가 없어 그 탭이면 항상 true.
    private(set) var isShowingRoute = false

    var isActive: Bool { destination != nil }

    /// 목록 페이지를 띄울 때: 길찾기 중이고 지도에 경로를 보이지 않는 단계.
    var isShowingList: Bool { isActive && !isShowingRoute }

    var selectedResult: ModeResult? { results[selectedMode] }

    var selectedTransitRoute: TransitRoute? {
        guard case let .transit(routes) = selectedResult, routes.indices.contains(selectedTransitIndex) else { return nil }
        return routes[selectedTransitIndex]
    }

    /// 지도에 그릴 경로. 목록 단계이거나, 아직 결과가 없거나 실패했으면 nil.
    var overlay: RouteOverlay? {
        guard isShowingRoute, let origin = originPoint, let end = destinationPoint else { return nil }
        switch selectedResult {
        case let .route(route):
            let kind: RouteLine.Kind = selectedMode == .walk ? .walk : .car
            return RouteOverlay(lines: [RouteLine(kind: kind, points: route.points)], start: origin, end: end)
        case .transit:
            guard let route = selectedTransitRoute else { return nil }
            var lines = route.legs.map { RouteLine(kind: Self.lineKind($0.kind), points: $0.points) }
            // 대중교통 응답은 첫 정류장부터 시작하므로, 출발지·도착지와 이어지는 도보 구간을 직선으로 덧붙인다.
            if let first = lines.first?.points.first, first != origin {
                lines.insert(RouteLine(kind: .walk, points: [origin, first]), at: 0)
            }
            if let last = lines.last?.points.last, last != end {
                lines.append(RouteLine(kind: .walk, points: [last, end]))
            }
            return RouteOverlay(lines: lines, start: origin, end: end)
        case .loading, .failed, nil:
            return nil
        }
    }

    let effects: AsyncStream<RouteEffect>

    @ObservationIgnored private let effectContinuation: AsyncStream<RouteEffect>.Continuation
    @ObservationIgnored private let findCarRoute: FindRouteUseCase
    @ObservationIgnored private let findWalkingRoute: FindWalkingRouteUseCase
    @ObservationIgnored private let findTransitRoutes: FindTransitRoutesUseCase
    /// 종료하거나 다시 찾은 뒤에 늦게 도착한 결과를 버린다.
    @ObservationIgnored private var generation = 0

    init(findCarRoute: FindRouteUseCase, findWalkingRoute: FindWalkingRouteUseCase, findTransitRoutes: FindTransitRoutesUseCase) {
        self.findCarRoute = findCarRoute
        self.findWalkingRoute = findWalkingRoute
        self.findTransitRoutes = findTransitRoutes
        (effects, effectContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        effectContinuation.finish()
    }

    // MARK: - 시작·변경

    /// 길찾기 준비 화면에서 정한 두 지점과 이동 수단으로 찾는다.
    func plan(_ plan: RoutePlan, myLocation: GeoPoint?) async {
        selectedMode = plan.mode
        await search(origin: plan.origin, destination: plan.destination, myLocation: myLocation)
    }

    /// 장소 상세의 "길찾기". 출발지는 내 위치다. 내 위치를 아직 모르면 시작하지 않는다.
    func start(to place: Place, myLocation: GeoPoint?) async {
        await search(origin: .myLocation, destination: .place(place), myLocation: myLocation)
    }

    /// 길찾기 중 출발지 줄 탭 → 선택 페이지에서 고른 값.
    func changeOrigin(_ origin: RouteEndpoint, myLocation: GeoPoint?) async {
        guard let destination else { return }
        await search(origin: origin, destination: destination, myLocation: myLocation)
    }

    /// 길찾기 중 도착지 줄 탭 → 선택 페이지에서 고른 값.
    func changeDestination(_ destination: RouteEndpoint, myLocation: GeoPoint?) async {
        guard let origin else { return }
        await search(origin: origin, destination: destination, myLocation: myLocation)
    }

    /// 출발지와 도착지를 맞바꾼다.
    func swap(myLocation: GeoPoint?) async {
        guard let origin, let destination else { return }
        await search(origin: destination, destination: origin, myLocation: myLocation)
    }

    /// 두 지점의 좌표를 정하고 세 이동 수단을 동시에 조회한다.
    /// 좌표를 정할 수 없거나 너무 가까우면 상태를 바꾸지 않고 안내만 한다.
    private func search(origin: RouteEndpoint, destination: RouteEndpoint, myLocation: GeoPoint?) async {
        guard let from = origin.point(myLocation: myLocation), let to = destination.point(myLocation: myLocation) else {
            effectContinuation.yield(.showMessage(String(
                localized: "map.message.findingLocation",
                defaultValue: "현재 위치를 찾고 있어요"
            )))
            return
        }
        // 너무 가까우면 어떤 수단으로도 찾을 필요가 없으므로 화면을 열지 않는다.
        do {
            try FindRouteUseCase.ensureFarEnough(from, to)
        } catch {
            effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
            return
        }

        generation += 1
        let generation = generation
        self.origin = origin
        self.destination = destination
        originPoint = from
        destinationPoint = to
        selectedTransitIndex = 0
        // 새로 찾으면 대중교통은 목록 단계부터, 자동차·도보는 바로 지도에 그린다(결과가 오면 카메라를 맞춘다).
        isShowingRoute = Self.drawsDirectly(selectedMode)
        results = Dictionary(uniqueKeysWithValues: TravelMode.allCases.map { ($0, ModeResult.loading) })

        // 세 수단을 동시에 요청하고, 도착하는 대로 탭에 반영한다.
        let (car, walk, transit) = (findCarRoute, findWalkingRoute, findTransitRoutes)
        await withTaskGroup(of: (TravelMode, ModeResult).self) { group in
            for mode in TravelMode.allCases {
                group.addTask {
                    (mode, await Self.fetch(mode, from: from, to: to, car: car, walk: walk, transit: transit))
                }
            }
            for await (mode, result) in group {
                guard generation == self.generation else { continue }
                results[mode] = result
                if mode == selectedMode, isShowingRoute { fitSelected() }
            }
        }
    }

    // MARK: - 목록 ↔ 지도

    /// 이동 수단 탭(목록 화면, 지도 위 탭). 다시 조회하지 않는다.
    /// 대중교통은 목록 단계로, 자동차·도보는 경로가 하나라 바로 지도에 그리고 카메라를 맞춘다.
    func selectMode(_ mode: TravelMode) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        selectedTransitIndex = 0
        isShowingRoute = Self.drawsDirectly(mode)
        fitSelected()
    }

    /// 목록에서 경로 탭. 지금 탭의 `index`번째 경로를 지도에 그리고 카메라를 맞춘다.
    func showRoute(at index: Int = 0) {
        selectedTransitIndex = index
        isShowingRoute = true
        fitSelected()
    }

    /// 대중교통 경로를 보던 중 ‹(뒤로). 지도 선을 지우고 목록 단계로 돌아간다.
    func backToList() {
        selectedMode = .transit
        isShowingRoute = false
    }

    /// 길찾기 카드·목록의 ✕. 결과를 지운다. 이동 수단 선택은 유지한다.
    func close() {
        generation += 1
        origin = nil
        destination = nil
        originPoint = nil
        destinationPoint = nil
        results = [:]
        selectedTransitIndex = 0
        isShowingRoute = false
    }

    /// 고를 후보 없이 바로 지도에 그리는 수단(카카오 도보 API는 경로 하나만 준다).
    private static func drawsDirectly(_ mode: TravelMode) -> Bool {
        mode != .transit
    }

    private func fitSelected() {
        if let overlay {
            effectContinuation.yield(.fitCamera(overlay.allPoints))
        }
    }

    private nonisolated static func fetch(
        _ mode: TravelMode,
        from origin: GeoPoint,
        to destination: GeoPoint,
        car: FindRouteUseCase,
        walk: FindWalkingRouteUseCase,
        transit: FindTransitRoutesUseCase
    ) async -> ModeResult {
        do {
            switch mode {
            case .car: return .route(try await car(from: origin, to: destination))
            case .walk: return .route(try await walk(from: origin, to: destination))
            case .transit: return .transit(try await transit(from: origin, to: destination))
            }
        } catch {
            return .failed(error as? DomainError ?? .unknown)
        }
    }

    private static func lineKind(_ kind: TransitLeg.Kind) -> RouteLine.Kind {
        switch kind {
        case .walk: .walk
        case .bus: .bus
        case .subway: .subway
        }
    }
}
