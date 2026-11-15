import Foundation

protocol LocationRepository: Sendable {
    func permission() async -> LocationPermission
    /// 권한 팝업을 띄우고 사용자가 응답한 결과를 돌려준다. 이미 결정된 상태면 바로 돌려준다.
    func requestPermission() async -> LocationPermission
    func lastKnownLocation() async -> UserLocation?
    /// 구독이 끝나면(onTermination) 위치 업데이트도 멈춰야 한다.
    func locationUpdates() async -> AsyncThrowingStream<UserLocation, any Error>
}
