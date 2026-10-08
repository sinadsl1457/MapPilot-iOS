import Foundation

/// 지도 상단 칩으로 바로 검색하는 장소 종류.
enum PlaceCategory: CaseIterable, Equatable, Sendable {
    case restaurant
    case cafe
    case convenienceStore
    case gasStation
    case pharmacy
    case parking
}
