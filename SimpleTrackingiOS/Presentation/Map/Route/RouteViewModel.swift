import Foundation
import Observation

enum RouteEffect: Equatable, Sendable {
    /// 경로 전체가 보이도록 카메라를 맞춘다.
    case fitCamera([GeoPoint])
    case showError(DomainError)
    case showMessage(String)
}

/// 길찾기 모드 상태. 출발지는 항상 내 위치다.
/// 시작하면 세 이동 수단을 동시에 조회해 탭마다 소요 시간을 보여준다(네이버 지도 방식).
@MainActor
@Observable
final class RouteViewModel {
    enum ModeResult: Equatable {
        case loading
        case route(Route)
        case transit([TransitRoute])
        case failed(DomainError)
    }

    private(set) var destination: Place?
    private(set) var origin: GeoPoint?
    /// 마지막으로 고른 이동 수단을 다음 길찾기에서도 유지한다.
    private(set) var selectedMode: TravelMode = .transit
    private(set) var results: [TravelMode: ModeResult] = [:]
    private(set) var selectedTransitIndex = 0

    var isActive: Bool { destination != nil }

    var selectedResult: ModeResult? { results[selectedMode] }

    var selectedTransitRoute: TransitRoute? {
        guard case let .transit(routes) = selectedResult, routes.indices.contains(selectedTransitIndex) else { return nil }
        return routes[selectedTransitIndex]
    }

    /// 지도에 그릴 경로. 아직 결과가 없거나 실패했으면 nil.
    var overlay: RouteOverlay? {
        guard let origin, let destination else { return nil }
        let end = destination.location
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

    /// - Parameter origin: 내 위치. 아직 모르면 길찾기를 시작하지 않는다.
    func start(to place: Place, from origin: GeoPoint?) async {
        guard let origin else {
            effectContinuation.yield(.showMessage(String(
                localized: "map.message.findingLocation",
                defaultValue: "현재 위치를 찾고 있어요"
            )))
            return
        }
        // 너무 가까우면 어떤 수단으로도 찾을 필요가 없으므로 화면을 열지 않는다.
        do {
            try FindRouteUseCase.ensureFarEnough(origin, place.location)
        } catch {
            effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
            return
        }

        generation += 1
        let generation = generation
        self.origin = origin
        destination = place
        selectedTransitIndex = 0
        results = Dictionary(uniqueKeysWithValues: TravelMode.allCases.map { ($0, ModeResult.loading) })

        let (car, walk, transit) = (findCarRoute, findWalkingRoute, findTransitRoutes)
        let end = place.location
        await withTaskGroup(of: (TravelMode, ModeResult).self) { group in
            for mode in TravelMode.allCases {
                group.addTask {
                    (mode, await Self.fetch(mode, from: origin, to: end, car: car, walk: walk, transit: transit))
                }
            }
            for await (mode, result) in group {
                guard generation == self.generation else { continue }
                results[mode] = result
                if mode == selectedMode { fitSelected() }
            }
        }
    }

    func selectMode(_ mode: TravelMode) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        selectedTransitIndex = 0
        fitSelected()
    }

    func selectTransitRoute(at index: Int) {
        selectedTransitIndex = index
        fitSelected()
    }

    func close() {
        generation += 1
        destination = nil
        origin = nil
        results = [:]
        selectedTransitIndex = 0
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
