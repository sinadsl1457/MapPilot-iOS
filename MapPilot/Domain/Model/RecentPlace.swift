import Foundation

/// 최근에 고른 장소와 고른 시각. 길찾기 준비 화면 목록에 쓴다(최근 검색어와 별개).
struct RecentPlace: Equatable, Sendable {
    let place: Place
    let usedAt: Date
}
