import Foundation

struct ObserveLocationUseCase: Sendable {
    static let maxAccuracyMeters = 50.0

    private let repository: any LocationRepository

    init(repository: any LocationRepository) {
        self.repository = repository
    }

    /// 마지막으로 알려진 위치를 먼저 내보내고 실시간 위치를 이어 붙인다.
    /// 정확도가 `maxAccuracyMeters`보다 나쁜 값은 걸러낸다.
    func callAsFunction() -> AsyncThrowingStream<UserLocation, any Error> {
        let repository = repository
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if let last = await repository.lastKnownLocation(), Self.isAccurate(last) {
                        continuation.yield(last)
                    }
                    for try await location in await repository.locationUpdates() where Self.isAccurate(location) {
                        continuation.yield(location)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func isAccurate(_ location: UserLocation) -> Bool {
        location.accuracyMeters <= maxAccuracyMeters
    }
}
