import Foundation

/// 도보·대중교통 응답 → Domain.
enum RoutingMapper {
    /// `[[경도, 위도]]` → GeoPoint. 값이 2개 미만인 항목은 버린다.
    static func points(_ path: PathDTO?) -> [GeoPoint] {
        (path?.points ?? []).compactMap { pair in
            pair.count >= 2 ? GeoPoint(latitude: pair[1], longitude: pair[0]) : nil
        }
    }

    static func walkingRoute(_ dto: WalkRouteDTO, origin: GeoPoint, destination: GeoPoint) -> Route {
        let roadPoints = dto.legs.flatMap(\.steps).flatMap { points($0.path) }
        return Route(
            points: [origin] + roadPoints + [destination],
            distanceMeters: dto.properties.totalDistance,
            durationSeconds: dto.properties.totalTime
        )
    }

    static func transitRoute(_ dto: TransitRouteDTO) -> TransitRoute {
        TransitRoute(
            kind: routeKind(dto.properties.type),
            durationSeconds: dto.properties.totalTime,
            distanceMeters: dto.properties.totalDistance,
            transfers: dto.properties.transfers,
            fare: dto.properties.fare?.value,
            legs: dto.steps.map(transitLeg)
        )
    }

    static func transitLeg(_ dto: TransitStepDTO) -> TransitLeg {
        TransitLeg(
            kind: legKind(dto.properties.type),
            durationSeconds: dto.properties.time,
            distanceMeters: dto.properties.distance,
            guidance: dto.properties.guidance ?? "",
            lineNames: uniqueNames(dto.properties.vehicles),
            stops: (dto.properties.stops ?? []).map(\.name),
            points: points(dto.path)
        )
    }

    private static func routeKind(_ type: String) -> TransitRoute.Kind {
        switch type {
        case "BUS": .bus
        case "SUBWAY": .subway
        default: .busAndSubway
        }
    }

    /// 모르는 종류는 도보로 본다.
    private static func legKind(_ type: String) -> TransitLeg.Kind {
        switch type {
        case "BUS": .bus
        case "SUBWAY": .subway
        default: .walk
        }
    }

    /// 같은 노선이 일반·급행으로 두 번 오기도 해서 이름 기준으로 중복을 지운다.
    private static func uniqueNames(_ vehicles: [NamedDTO]?) -> [String] {
        var seen = Set<String>()
        return (vehicles ?? []).map(\.name).filter { seen.insert($0).inserted }
    }

    /// 실패 상태 → DomainError.
    static func error(forStatus status: String) -> DomainError {
        switch status {
        case "SAME_POINT", "EQUAL_POINTS": .destinationTooClose
        default: .routeNotFound(reason: status)
        }
    }
}
