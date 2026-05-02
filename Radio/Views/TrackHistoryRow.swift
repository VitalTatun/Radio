import AppKit
import SwiftUI

struct TrackHistoryRow: View {
    let item: TrackHistoryItem

    private var artworkImage: NSImage? {
        guard let artworkData = item.artworkData else {
            return nil
        }

        return NSImage(data: artworkData)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if let artworkImage {
                    Image(nsImage: artworkImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(item.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(item.stationName) • \(item.playedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
