import Foundation

/// Info.plist에 `$(…)`로 주입된 설정값. 실제 값은 git에 올라가지 않는 Secrets.xcconfig에 있다.
struct AppSecrets: Sendable {
    let kakaoNativeAppKey: String
    let kakaoRestAPIKey: String
    /// 값이 있으면 GPS 대신 이 좌표를 내 위치로 쓴다.
    var fixedLocation: GeoPoint? = nil

    static func load(from bundle: Bundle = .main) -> AppSecrets {
        AppSecrets(
            kakaoNativeAppKey: value(for: "KAKAO_NATIVE_APP_KEY", in: bundle),
            kakaoRestAPIKey: value(for: "KAKAO_REST_API_KEY", in: bundle),
            fixedLocation: parseGeoPoint(value(for: "FIXED_LOCATION", in: bundle))
        )
    }

    /// "위도,경도" → GeoPoint. 형식이 틀리거나 범위를 벗어나면 nil.
    static func parseGeoPoint(_ text: String) -> GeoPoint? {
        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let latitude = Double(parts[0]), let longitude = Double(parts[1]),
              (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// 키가 없거나 빌드 변수가 치환되지 않은 채(`$(…)`) 남아 있으면 빈 문자열.
    private static func value(for key: String, in bundle: Bundle) -> String {
        let raw = (bundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.hasPrefix("$(") ? "" : raw
    }
}
