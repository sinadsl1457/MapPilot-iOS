import Foundation

/// 대중교통 경로 하나. 여러 구간(도보·버스·지하철)으로 이루어진다.
struct TransitRoute: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case bus, subway, busAndSubway
    }

    let kind: Kind
    let durationSeconds: Int
    let distanceMeters: Int
    let transfers: Int
    /// 원 단위. 알 수 없으면 nil.
    let fare: Int?
    let legs: [TransitLeg]
}

struct TransitLeg: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case walk, bus, subway
    }

    let kind: Kind
    let durationSeconds: Int
    let distanceMeters: Int
    /// 예: "수인분당선 (태평 > 왕십리)", "왕십리역 환승"
    let guidance: String
    /// 탈 수 있는 노선 이름. 버스는 여러 개일 수 있다. 도보면 비어 있다.
    let lineNames: [String]
    /// 지나는 정류장·역 이름. 첫 번째가 타는 곳, 마지막이 내리는 곳이다.
    let stops: [String]
    let points: [GeoPoint]
}
