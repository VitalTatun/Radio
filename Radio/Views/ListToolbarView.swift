import SwiftUI

struct ListToolbarView: View {
    let sectionTitle: LocalizedStringResource
    let listMode: ContentViewModel.ListMode
    let canAddStation: Bool
    let isTrackHistoryEmpty: Bool
    let onToggleListMode: () -> Void
    let onClearHistory: () -> Void
    let onAddStation: () -> Void

    private let buttonHeight: CGFloat = 24
    private let buttonWidth: CGFloat = 28

    var body: some View {
        HStack {
            Text(sectionTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onToggleListMode) {
                toolbarButtonLabel(
                    systemName: listMode == .history ? "dot.radiowaves.left.and.right" : "music.note.list"
                )
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(L10n.string(L10n.actionHistory))
            .accessibilityLabel(L10n.string(L10n.actionHistory))

            if listMode == .history {
                Button(action: onClearHistory) {
                    toolbarButtonLabel(systemName: "trash")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(L10n.string(L10n.actionClearHistory))
                .accessibilityLabel(L10n.string(L10n.actionClearHistory))
                .disabled(isTrackHistoryEmpty)
            }

            if listMode == .stations {
                if canAddStation {
                    Button(action: onAddStation) {
                        toolbarButtonLabel(systemName: "plus")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(L10n.string(L10n.actionAddStation))
                    .accessibilityLabel(L10n.string(L10n.actionAddStation))
                } else {
                    Text(L10n.stationsLimitReached)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toolbarButtonLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: buttonWidth, height: buttonHeight)
    }
}
