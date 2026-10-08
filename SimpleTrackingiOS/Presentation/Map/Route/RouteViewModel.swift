import Foundation
import Observation

enum RouteEffect: Equatable, Sendable {
    /// 경로 전체가 보이도록 카메라를 맞춘다.
    case fitCamera([GeoPoint])
    case showError(DomainError)
    case showMessage(String)
}

/// 길찾기 모드 상태. 출발지는 항상 내 위치, 이동 수단은 자동차뿐이다(카카오모빌리티 API 제약).
@MainActor
@Observable
final class RouteViewModel {
    enum Phase: Equatable {
        case loading
        case loaded(Route)
    }

    private(set) var destination: Place?
    private(set) var phase: Phase?

    var isActive: Bool { destination != nil }

    var route: Route? {
        if case let .loaded(route) = phase { route } else { nil }
    }

    let effects: AsyncStream<RouteEffect>

    @ObservationIgnored private let effectContinuation: AsyncStream<RouteEffect>.Continuation
    @ObservationIgnored private let findRoute: FindRouteUseCase
    /// 종료하거나 다시 찾은 뒤에 늦게 도착한 결과를 버린다.
    @ObservationIgnored private var generation = 0

    init(findRoute: FindRouteUseCase) {
        self.findRoute = findRoute
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

        generation += 1
        let generation = generation
        destination = place
        phase = .loading

        do {
            let route = try await findRoute(from: origin, to: place.location)
            guard generation == self.generation else { return }
            phase = .loaded(route)
            effectContinuation.yield(.fitCamera(route.points))
        } catch {
            guard generation == self.generation else { return }
            close()
            guard !(error is CancellationError) else { return }
            effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
        }
    }

    func close() {
        generation += 1
        destination = nil
        phase = nil
    }
}
