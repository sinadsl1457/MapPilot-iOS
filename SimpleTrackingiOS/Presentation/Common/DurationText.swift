import Foundation

enum DurationText {
    /// 분 단위로 올림한다. 예: 45초 → "1분", 1500초 → "25분", 3906초 → "1시간 6분", 7200초 → "2시간"
    static func string(seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return String(localized: "duration.minutes \(rest)")
        case (_, 0): return String(localized: "duration.hours \(hours)")
        default: return String(localized: "duration.hoursMinutes \(hours) \(rest)")
        }
    }
}
