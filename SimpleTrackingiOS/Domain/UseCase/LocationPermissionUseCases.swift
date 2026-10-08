import Foundation

struct GetLocationPermissionUseCase: Sendable {
    private let repository: any LocationRepository

    init(repository: any LocationRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> LocationPermission {
        await repository.permission()
    }
}

struct RequestLocationPermissionUseCase: Sendable {
    private let repository: any LocationRepository

    init(repository: any LocationRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> LocationPermission {
        await repository.requestPermission()
    }
}
