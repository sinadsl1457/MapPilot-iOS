import SwiftUI

/// 지도 위에 떠 있는 검색창. 누르면 검색 페이지가 열린다.
struct MapSearchBar: View {
    let keyword: String?
    let showsClear: Bool
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Group {
                        if let keyword {
                            Text(keyword).foregroundStyle(.primary)
                        } else {
                            Text("search.placeholder").foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsClear {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("search.clearResults"))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 48)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}
