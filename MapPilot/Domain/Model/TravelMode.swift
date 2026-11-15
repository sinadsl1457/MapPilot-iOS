import Foundation

/// 길찾기 이동 수단. 탭 순서대로 나열한다.
enum TravelMode: CaseIterable, Equatable, Hashable, Sendable {
    case transit
    case car
    case walk
}
