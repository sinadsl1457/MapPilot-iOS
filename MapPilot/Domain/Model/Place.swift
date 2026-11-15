import Foundation

struct Place: Equatable, Sendable {
    let id: String
    let name: String
    let category: String
    let address: String
    let phone: String
    let location: GeoPoint
    /// 기준 좌표 없이 검색하면 nil.
    let distanceMeters: Int?
}
