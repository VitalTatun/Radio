import SwiftUI

struct TrackHistoryListSection: View {
    let items: [TrackHistoryItem]

    var body: some View {
        if items.isEmpty {
            Text(L10n.historyEmpty)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    TrackHistoryRow(item: item)
                }
            }
        }
    }
}
