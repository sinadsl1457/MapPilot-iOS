import Foundation

enum RouteMapper {
    /// 요약 정보가 없으면 nil.
    static func map(_ dto: RouteDTO, origin: GeoPoint, destination: GeoPoint) -> Route? {
        guard let summary = dto.summary else { return nil }
        let roadPoints = (dto.sections ?? [])
            .flatMap(\.roads)
            .flatMap { points(fromVertexes: $0.vertexes) }
        return Route(
            points: [origin] + roadPoints + [destination],
            distanceMeters: summary.distance,
            durationSeconds: summary.duration
        )
    }

    /// `[경도, 위도, 경도, 위도, …]`를 2개씩 묶는다. 짝이 맞지 않는 마지막 값은 버린다.
    static func points(fromVertexes vertexes: [Double]) -> [GeoPoint] {
        stride(from: 0, to: vertexes.count - 1, by: 2).map { i in
            GeoPoint(latitude: vertexes[i + 1], longitude: vertexes[i])
        }
    }
}
