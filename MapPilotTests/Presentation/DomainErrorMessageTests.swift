import Testing
@testable import MapPilot

struct DomainErrorMessageTests {
    @Test(arguments: [
        (DomainError.network, "네트워크 연결을 확인해주세요"),
        (.unauthorized, "카카오 API 키 인증에 실패했어요"),
        (.quotaExceeded, "요청 한도를 초과했어요. 잠시 후 다시 시도해주세요"),
        (.server(code: 500), "서버에 문제가 생겼어요"),
        (.emptyQuery, "검색어를 입력해주세요"),
        (.destinationTooClose, "이미 목적지 근처에 있어요"),
        (.routeNotFound(reason: "경로 없음"), "경로를 찾을 수 없어요"),
        (.locationPermissionDenied, "위치 권한이 필요해요"),
        (.unknown, "알 수 없는 오류가 발생했어요"),
    ])
    func mapsEveryErrorToKoreanMessage(error: DomainError, expected: String) {
        #expect(error.userMessage == expected)
    }
}
