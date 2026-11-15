import CoreLocation

/// CLLocationManager 래퍼. 구독자가 하나라도 있는 동안만 GPS를 켠다.
@MainActor
final class LocationRepositoryImpl: NSObject {
    private typealias Continuation = AsyncThrowingStream<UserLocation, any Error>.Continuation

    private let manager: CLLocationManager
    private var subscribers: [UUID: Continuation] = [:]
    private var permissionWaiters: [CheckedContinuation<LocationPermission, Never>] = []

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.delegate = self
    }

    private func unsubscribe(_ id: UUID) {
        guard subscribers.removeValue(forKey: id) != nil, subscribers.isEmpty else { return }
        manager.stopUpdatingLocation()
    }

    private func finishAll(throwing error: DomainError) {
        let finishing = subscribers.values
        subscribers.removeAll()
        manager.stopUpdatingLocation()
        finishing.forEach { $0.finish(throwing: error) }
    }

    private static func permission(from status: CLAuthorizationStatus) -> LocationPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}

// 프로토콜의 async 요구사항은 nonisolated라서, 명시하지 않으면 구현 메서드도 nonisolated로 추론된다.
// 메서드마다 @MainActor를 붙여 CLLocationManager를 메인 액터에서만 만지도록 한다.
extension LocationRepositoryImpl: LocationRepository {
    @MainActor func permission() async -> LocationPermission {
        Self.permission(from: manager.authorizationStatus)
    }

    @MainActor func requestPermission() async -> LocationPermission {
        let current = Self.permission(from: manager.authorizationStatus)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            permissionWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    @MainActor func lastKnownLocation() async -> UserLocation? {
        guard Self.permission(from: manager.authorizationStatus) == .authorized else { return nil }
        return manager.location.map(UserLocationMapper.map)
    }

    @MainActor func locationUpdates() async -> AsyncThrowingStream<UserLocation, any Error> {
        let (stream, continuation) = AsyncThrowingStream<UserLocation, any Error>.makeStream()
        guard Self.permission(from: manager.authorizationStatus) != .denied else {
            continuation.finish(throwing: DomainError.locationPermissionDenied)
            return stream
        }

        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.unsubscribe(id) }
        }
        if subscribers.count == 1 {
            manager.startUpdatingLocation()
        }
        return stream
    }
}

extension LocationRepositoryImpl: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let permission = Self.permission(from: manager.authorizationStatus)
        // 매니저를 만들 때도 한 번 호출되므로 아직 결정 전이면 기다리던 쪽을 깨우지 않는다.
        guard permission != .notDetermined else { return }

        let waiters = permissionWaiters
        permissionWaiters.removeAll()
        waiters.forEach { $0.resume(returning: permission) }

        if permission == .denied {
            finishAll(throwing: .locationPermissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            let mapped = UserLocationMapper.map(location)
            subscribers.values.forEach { $0.yield(mapped) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // locationUnknown 같은 일시적 오류는 CoreLocation이 계속 재시도하므로 무시한다.
        if (error as? CLError)?.code == .denied {
            finishAll(throwing: .locationPermissionDenied)
        }
    }
}
