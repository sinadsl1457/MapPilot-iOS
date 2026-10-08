import Foundation

/// `GET /v1/directions` 응답.
struct DirectionsResponseDTO: Decodable, Sendable {
    let routes: [RouteDTO]
}

struct RouteDTO: Decodable, Sendable {
    let resultCode: Int
    let resultMsg: String
    /// 길찾기에 실패하면(`resultCode != 0`) 내려오지 않는다.
    let summary: RouteSummaryDTO?
    let sections: [RouteSectionDTO]?
}

struct RouteSummaryDTO: Decodable, Sendable {
    let distance: Int
    let duration: Int
}

struct RouteSectionDTO: Decodable, Sendable {
    let roads: [RoadDTO]
}

struct RoadDTO: Decodable, Sendable {
    /// `[경도, 위도, 경도, 위도, …]`로 평탄화된 좌표.
    let vertexes: [Double]
}
