import SwiftUI

struct StationRow: View {
    enum Indicator {
        case loading
        case playing

        var systemName: String {
            switch self {
            case .loading:
                "circle.dashed"
            case .playing:
                "play.fill"
            }
        }

        var shouldRotate: Bool {
            switch self {
            case .loading:
                true
            case .playing:
                false
            }
        }
    }

    let station: Station
    let indicator: Indicator?
    @Binding var hoveredStationID: Station.ID?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isHovered: Bool {
        hoveredStationID == station.id
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Group {
                    if let indicator {
                        if indicator.shouldRotate {
                            Image(systemName: indicator.systemName)
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.rotate, options: .repeating)
                        } else {
                            Image(systemName: indicator.systemName)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 14, height: 14)

                Text(station.name)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.secondary.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering in
            hoveredStationID = isHovering ? station.id : nil
        }
        .contextMenu {
            Button(L10n.actionEdit, action: onEdit)

            Button(role: .destructive, action: onDelete) {
                Text(L10n.actionDelete)
            }
        }
    }
}
