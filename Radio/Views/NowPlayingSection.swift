import AppKit
import SwiftUI

struct NowPlayingSection: View {
    let artwork: NSImage?
    let title: String
    let artist: String
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(5)
        .background(Color(.tertiarySystemFill))
        .animation(.easeInOut(duration: 0.25), value: isPlaying)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
