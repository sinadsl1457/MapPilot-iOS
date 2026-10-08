import Foundation
@testable import SimpleTrackingiOS

/// `updates`를 순서대로 내보낸 뒤 `failure`가 있으면 에러로, 없으면 정상 종료한다.
/// `keepsStreamOpen`이 true면 값을 다 내보낸 뒤에도 끝나지 않는다.
actor FakeLocationRepository: LocationRepository {
    private(set) var requestPermissionCount = 0
    private var currentPermission: LocationPermission
    private let permissionAfterRequest: LocationPermission
    private let lastKnown: UserLocation?
    private let updates: [UserLocation]
    private let failure: (any Error)?
    private let keepsStreamOpen: Bool

    init(
        permission: LocationPermission = .authorized,
        permissionAfterRequest: LocationPermission = .authorized,
        lastKnown: UserLocation? = nil,
        updates: [UserLocation] = [],
        failure: (any Error)? = nil,
        keepsStreamOpen: Bool = false
    ) {
        self.currentPermission = permission
        self.permissionAfterRequest = permissionAfterRequest
        self.lastKnown = lastKnown
        self.updates = updates
        self.failure = failure
        self.keepsStreamOpen = keepsStreamOpen
    }

    func permission() async -> LocationPermission {
        currentPermission
    }

    func requestPermission() async -> LocationPermission {
        requestPermissionCount += 1
        currentPermission = permissionAfterRequest
        return currentPermission
    }

    func lastKnownLocation() async -> UserLocation? {
        lastKnown
    }

    func locationUpdates() async -> AsyncThrowingStream<UserLocation, any Error> {
        let (stream, continuation) = AsyncThrowingStream<UserLocation, any Error>.makeStream()
        for update in updates {
            continuation.yield(update)
        }
        if let failure {
            continuation.finish(throwing: failure)
        } else if !keepsStreamOpen {
            continuation.finish()
        }
        return stream
    }
}
