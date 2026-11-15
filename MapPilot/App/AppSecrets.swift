import Foundation

/// Info.plist에 `$(…)`로 주입된 설정값. 실제 값은 git에 올라가지 않는 Secrets.xcconfig에 있다.
struct AppSecrets: Sendable {
    let kakaoNativeAppKey: String
    let kakaoRestAPIKey: String

    static func load(from bundle: Bundle = .main) -> AppSecrets {
        AppSecrets(
            kakaoNativeAppKey: value(for: "KAKAO_NATIVE_APP_KEY", in: bundle),
            kakaoRestAPIKey: value(for: "KAKAO_REST_API_KEY", in: bundle)
        )
    }

    /// 키가 없거나 빌드 변수가 치환되지 않은 채(`$(…)`) 남아 있으면 빈 문자열.
    private static func value(for key: String, in bundle: Bundle) -> String {
        let raw = (bundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.hasPrefix("$(") ? "" : raw
    }
}
