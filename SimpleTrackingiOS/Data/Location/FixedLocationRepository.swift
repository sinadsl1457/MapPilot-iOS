import Foundation

/// GPS 대신 정해진 좌표를 내 위치로 돌려준다. 권한은 항상 허용된 것으로 본다.
/// 시뮬레이터처럼 실제 위치를 받을 수 없는 환경에서 연습용으로 쓴다.
struct FixedLocationRepository: LocationRepository {
    let point: GeoPoint

    func permission() async -> LocationPermission { .authorized }

    func requestPermission() async -> LocationPermission { .authorized }

    func lastKnownLocation() async -> UserLocation? { location() }

    /// 고정 위치를 한 번 내보내고, 구독이 끝날 때까지 열어 둔다.
    func locationUpdates() async -> AsyncThrowingStream<UserLocation, any Error> {
        let (stream, continuation) = AsyncThrowingStream<UserLocation, any Error>.makeStream()
        continuation.yield(location())
        return stream
    }

    private func location() -> UserLocation {
        UserLocation(point: point, bearing: nil, accuracyMeters: 5, timestamp: .now)
    }
}
