import Testing
@testable import SimpleTrackingiOS

struct DurationTextTests {
    @Test(arguments: [
        (0, "1분"),
        (45, "1분"),
        (60, "1분"),
        (61, "2분"),
        (1_500, "25분"),
        (3_600, "1시간"),
        (3_906, "1시간 6분"),
        (7_200, "2시간"),
    ])
    func formats(seconds: Int, expected: String) {
        #expect(DurationText.string(seconds: seconds) == expected)
    }
}
