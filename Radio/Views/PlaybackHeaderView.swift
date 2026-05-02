import SwiftUI

struct PlaybackHeaderView: View {
    let stationName: String
    let statusText: String
    let isPlaying: Bool
    let canRestart: Bool
    let onTogglePlayback: () -> Void
    let onRestart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stationName)
                    .font(.headline)
                    .lineLimit(1)

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onTogglePlayback) {
                PlaybackControlIcon(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(isPlaying ? L10n.string(L10n.actionPause) : L10n.string(L10n.actionPlay))
            .accessibilityLabel(isPlaying ? L10n.string(L10n.actionPause) : L10n.string(L10n.actionPlay))

            Button(action: onRestart) {
                PlaybackControlIcon(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(L10n.string(L10n.actionRestartStream))
            .accessibilityLabel(L10n.string(L10n.actionRestartStream))
            .disabled(!canRestart)
        }
    }
}

private struct PlaybackControlIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 28, height: 28)
    }
}
