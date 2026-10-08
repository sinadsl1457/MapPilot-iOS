import Foundation

// `GET /v2/routing/walk`, `GET /v2/routing/publictraffic` 응답.
// 필드 이름이 이미 camelCase라 snake_case 변환의 영향을 받지 않는다.

struct PathDTO: Decodable, Sendable {
    /// `[[경도, 위도], …]`
    let points: [[Double]]
}

// MARK: - 도보

struct WalkResponseDTO: Decodable, Sendable {
    /// `OK`, `SAME_POINT`, `TOO_FAR_AWAY`, `ROUTE_RESULT_NOT_FOUND` 등
    let status: String
    let route: WalkRouteDTO?
}

struct WalkRouteDTO: Decodable, Sendable {
    let properties: WalkRoutePropertiesDTO
    let legs: [WalkLegDTO]
}

struct WalkRoutePropertiesDTO: Decodable, Sendable {
    let totalDistance: Int
    let totalTime: Int
}

struct WalkLegDTO: Decodable, Sendable {
    let steps: [WalkStepDTO]
}

struct WalkStepDTO: Decodable, Sendable {
    let path: PathDTO?
}

// MARK: - 대중교통

struct TransitResponseDTO: Decodable, Sendable {
    /// `OK`, `EQUAL_POINTS`, `NO_RESULTS`, `STARTNODES_NULL` 등
    let status: String
    let routes: [TransitRouteDTO]?
}

struct TransitRouteDTO: Decodable, Sendable {
    let properties: TransitRoutePropertiesDTO
    let steps: [TransitStepDTO]
}

struct TransitRoutePropertiesDTO: Decodable, Sendable {
    /// `BUS`, `SUBWAY`, `BUS_AND_SUBWAY`
    let type: String
    let totalDistance: Int
    let totalTime: Int
    let transfers: Int
    let fare: FareDTO?
}

struct FareDTO: Decodable, Sendable {
    let value: Int?
}

struct TransitStepDTO: Decodable, Sendable {
    let properties: TransitStepPropertiesDTO
    let path: PathDTO?
}

struct TransitStepPropertiesDTO: Decodable, Sendable {
    let guidance: String?
    /// `BUS`, `SUBWAY`, `WALKING`
    let type: String
    let distance: Int
    let time: Int
    let stops: [NamedDTO]?
    let vehicles: [NamedDTO]?
}

struct NamedDTO: Decodable, Sendable {
    let name: String
}
