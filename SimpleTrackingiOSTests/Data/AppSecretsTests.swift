import Foundation
import Testing
@testable import SimpleTrackingiOS

struct AppSecretsTests {
    @Test func appBundleContainsKeyEntries() {
        // 키 값은 개발자 환경마다 다르므로 Info.plist에 항목이 있는지만 확인한다.
        #expect(Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") is String)
        #expect(Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") is String)
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
            == "현재 위치를 지도에 표시하기 위해 사용합니다")
    }
}
