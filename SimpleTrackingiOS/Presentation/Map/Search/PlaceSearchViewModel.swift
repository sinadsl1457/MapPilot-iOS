import Foundation
import Observation

/// 키워드·카테고리 검색, 결과 선택, 검색 페이지(입력 중 실시간 미리보기 포함).
/// 상태 → MapScreen이 하단 시트와 지도 핀으로 그림 / effect → 카메라 이동, 오류 토스트.
@MainActor
@Observable
final class PlaceSearchViewModel {
    enum Source: Equatable {
        case keyword(String)
        case category(PlaceCategory)
    }

    enum Phase: Equatable {
        case loading
        case loaded([Place])
    }

    /// 검색창에 입력 중인 글자.
    var query = ""
    var isSearchPagePresented = false
    /// 검색 페이지에서 키워드 검색이 진행 중인지. 성공하면 페이지가 닫힌다.
    private(set) var isSubmitting = false

    /// 지금 지도에 보이는 결과가 어디서 왔는지. nil이면 결과 없음(시트 숨김).
    private(set) var source: Source?
    private(set) var phase: Phase?
    private(set) var selectedPlace: Place?
    private(set) var recentQueries: [String] = []

    // 실시간 검색(입력 중 미리보기)
    /// 지금 입력(공백 정리한 값). 비어 있으면 미리보기 없음 → 최근 검색어.
    private(set) var suggestFor = ""
    /// 화면에 보이는 미리보기 장소. 새 입력의 결과가 올 때까지 이전 결과를 그대로 둔다(깜빡임 방지).
    private(set) var suggestions: [Place] = []
    /// `suggestions`가 어떤 검색어의 결과인지. 입력 중에는 `suggestFor`와 다를 수 있다.
    private(set) var suggestionsQuery = ""
    /// 미리보기 요청이 대기 중이거나 진행 중인지.
    private(set) var isSuggesting = false

    /// 지금 입력의 결과가 도착했는데 비어 있을 때만 "결과 없음"을 보인다.
    var isSuggestionEmpty: Bool {
        !isSuggesting && suggestions.isEmpty && suggestionsQuery == suggestFor
    }

    let effects: AsyncStream<PlaceSearchEffect>

    var places: [Place] {
        if case let .loaded(places) = phase { places } else { [] }
    }

    var selectedCategory: PlaceCategory? {
        if case let .category(category) = source { category } else { nil }
    }

    var keyword: String? {
        if case let .keyword(keyword) = source { keyword } else { nil }
    }

    @ObservationIgnored private let effectContinuation: AsyncStream<PlaceSearchEffect>.Continuation
    @ObservationIgnored private let searchPlaces: SearchPlacesUseCase
    @ObservationIgnored private let searchPlacesByCategory: SearchPlacesByCategoryUseCase
    @ObservationIgnored private let recentSearches: RecentSearchesUseCase
    /// 늦게 도착한 이전 검색 결과가 최신 결과를 덮어쓰지 않게 한다.
    @ObservationIgnored private var generation = 0
    /// 실시간 검색: 입력이 이만큼 멈추면 요청한다(글자마다 요청하지 않게).
    @ObservationIgnored private let suggestDelay: Duration
    /// 대기 중(또는 진행 중)인 미리보기 요청. 새 입력·제출·정리 때 취소한다.
    @ObservationIgnored private var suggestTask: Task<Void, Never>?

    init(
        searchPlaces: SearchPlacesUseCase,
        searchPlacesByCategory: SearchPlacesByCategoryUseCase,
        recentSearches: RecentSearchesUseCase,
        suggestDelay: Duration = .milliseconds(300)
    ) {
        self.searchPlaces = searchPlaces
        self.searchPlacesByCategory = searchPlacesByCategory
        self.recentSearches = recentSearches
        self.suggestDelay = suggestDelay
        (effects, effectContinuation) = AsyncStream.makeStream()
    }

    isolated deinit {
        suggestTask?.cancel()
        effectContinuation.finish()
    }

    func onAppear() async {
        recentQueries = await recentSearches.list()
    }

    // MARK: - 검색 페이지

    /// 지도 검색창 탭. 지금 보고 있는 키워드로 입력칸을 채운 채 검색 페이지를 연다.
    /// 지난 미리보기는 지운다(입력을 시작하면 다시 찾는다).
    func openSearchPage() {
        cancelSuggest()
        query = keyword ?? ""
        suggestFor = ""
        suggestions = []
        suggestionsQuery = ""
        isSearchPagePresented = true
    }

    /// 검색 페이지 뒤로 버튼. 대기 중인 미리보기 요청은 보내지 않는다.
    func closeSearchPage() {
        cancelSuggest()
        isSearchPagePresented = false
    }

    /// 검색 페이지 입력칸이 바뀔 때마다(실시간 검색).
    /// 입력이 `suggestDelay` 동안 멈추면 그 검색어로 미리보기를 찾는다. 연달아 입력하면 마지막 것만 요청한다.
    /// 공백만 바뀌어 검색어가 같으면 다시 찾지 않는다. 입력을 다 지우면 미리보기를 비운다(최근 검색어로 돌아감).
    func onQueryChanged(_ text: String, center: GeoPoint?) {
        query = text
        let normalized = QueryNormalizer.normalize(text)
        guard normalized != suggestFor else { return }
        cancelSuggest()
        suggestFor = normalized
        guard !normalized.isEmpty else {
            suggestions = []
            suggestionsQuery = ""
            return
        }
        isSuggesting = true
        suggestTask = Task { [weak self, suggestDelay] in
            try? await Task.sleep(for: suggestDelay)
            guard !Task.isCancelled else { return }
            await self?.suggest(normalized, center: center)
        }
    }

    /// 미리보기에서 장소 탭. 다시 요청하지 않고 미리보기 결과를 그대로 지도에 띄운 뒤 그 장소를 고른다.
    /// 검색어는 최근 검색어에 남긴다.
    func pickSuggestion(_ place: Place) async {
        // 입력이 더 진행됐어도 이 목록을 찾은 검색어로 남긴다.
        let keyword = suggestionsQuery
        let places = suggestions
        cancelSuggest()
        generation += 1 // 진행 중이던 제출 검색이 있으면 버린다
        isSubmitting = false
        isSearchPagePresented = false
        source = .keyword(keyword)
        phase = .loaded(places)
        select(place)
        recentQueries = await recentSearches.add(keyword)
    }

    /// 키워드 검색. 성공하면 검색 페이지를 닫고 결과를 지도에 띄운다. 실패하면 페이지에 머문다.
    /// - Parameter center: 거리 계산 기준(보통 내 위치).
    func submit(center: GeoPoint?) async {
        cancelSuggest() // 전체 검색을 하므로 미리보기 요청은 필요 없다
        let generation = beginSearch()
        isSubmitting = true
        defer { if generation == self.generation { isSubmitting = false } }

        do {
            let places = try await searchPlaces(query: query, center: center)
            guard generation == self.generation else { return }
            let keyword = QueryNormalizer.normalize(query)
            recentQueries = await recentSearches.add(keyword)
            isSearchPagePresented = false
            show(places, from: .keyword(keyword))
        } catch {
            guard generation == self.generation else { return }
            report(error)
        }
    }

    func searchRecent(_ recent: String, center: GeoPoint?) async {
        query = recent
        await submit(center: center)
    }

    func removeRecent(_ recent: String) async {
        recentQueries = await recentSearches.remove(recent)
    }

    func clearRecents() async {
        await recentSearches.clear()
        recentQueries = []
    }

    // MARK: - 카테고리

    /// 같은 칩을 다시 누르면 결과를 지운다.
    func toggleCategory(_ category: PlaceCategory, around center: GeoPoint) async {
        if selectedCategory == category {
            clearResults()
            return
        }
        let generation = beginSearch()
        source = .category(category)
        phase = .loading
        do {
            let places = try await searchPlacesByCategory(category, around: center)
            guard generation == self.generation else { return }
            show(places, from: .category(category))
        } catch {
            guard generation == self.generation else { return }
            clearResults()
            report(error)
        }
    }

    // MARK: - 결과·선택

    func select(_ place: Place) {
        selectedPlace = place
        effectContinuation.yield(.focus(place.location))
    }

    /// 지도 마커를 탭했을 때.
    func selectPlace(id: String) {
        guard let place = places.first(where: { $0.id == id }) else { return }
        select(place)
    }

    /// 상세에서 목록으로 돌아간다.
    func deselectPlace() {
        selectedPlace = nil
    }

    func clearResults() {
        generation += 1
        cancelSuggest()
        source = nil
        phase = nil
        selectedPlace = nil
        query = ""
    }

    private func suggest(_ query: String, center: GeoPoint?) async {
        let places = try? await searchPlaces(query: query, center: center)
        // 그사이 다른 입력·제출·정리가 있었으면 취소돼 버린다.
        guard !Task.isCancelled else { return }
        isSuggesting = false
        suggestionsQuery = query
        // 미리보기 실패는 조용히 비운다(글자마다 오류 토스트를 띄우지 않는다). 엔터 검색은 오류를 보인다.
        suggestions = places ?? []
    }

    /// 대기 중인 미리보기 요청을 보내지 않고, 진행 중인 응답은 버린다.
    private func cancelSuggest() {
        suggestTask?.cancel()
        suggestTask = nil
        isSuggesting = false
    }

    /// 테스트 전용: 대기 중인 미리보기 요청이 끝날 때까지 기다린다.
    func waitForSuggestion() async {
        await suggestTask?.value
    }

    private func beginSearch() -> Int {
        generation += 1
        selectedPlace = nil
        return generation
    }

    private func show(_ places: [Place], from source: Source) {
        self.source = source
        phase = .loaded(places)
        if !places.isEmpty {
            effectContinuation.yield(.fitCamera(places.map(\.location)))
        }
    }

    private func report(_ error: any Error) {
        guard !(error is CancellationError) else { return }
        effectContinuation.yield(.showError(error as? DomainError ?? .unknown))
    }
}
