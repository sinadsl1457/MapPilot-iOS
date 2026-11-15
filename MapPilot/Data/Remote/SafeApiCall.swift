import Foundation

/// 2xx가 아닌 HTTP 응답. `safeApiCall`이 `DomainError`로 바꾼다.
struct HTTPStatusError: Error, Equatable {
    let statusCode: Int
}

/// 네트워크 호출에서 나온 오류를 `DomainError`로 바꾼다. 취소는 그대로 다시 던진다.
func safeApiCall<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as DomainError {
        throw error
    } catch let error as CancellationError {
        throw error
    } catch let error as HTTPStatusError {
        throw switch error.statusCode {
        case 401, 403: DomainError.unauthorized
        case 429: DomainError.quotaExceeded
        default: DomainError.server(code: error.statusCode)
        }
    } catch let error as URLError {
        // Task가 취소되면 URLSession은 CancellationError 대신 URLError(.cancelled)를 던진다.
        if error.code == .cancelled, Task.isCancelled { throw CancellationError() }
        throw DomainError.network
    } catch is DecodingError {
        throw DomainError.unknown
    } catch {
        throw DomainError.unknown
    }
}
