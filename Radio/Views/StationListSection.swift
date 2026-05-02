import SwiftUI

struct StationListSection: View {
    let stations: [Station]
    let selectedStationID: Station.ID?
    let isLoadingStation: Bool
    let isPlaying: Bool
    @Binding var hoveredStationID: Station.ID?
    let canAddStation: Bool
    let onSelect: (Station) -> Void
    let onEdit: (Station) -> Void
    let onDelete: (Station) -> Void

    var body: some View {
        if stations.isEmpty {
            Text(L10n.stationsEmpty)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 4) {
                ForEach(stations) { station in
                    StationRow(
                        station: station,
                        indicator: indicator(for: station),
                        hoveredStationID: $hoveredStationID,
                        onSelect: {
                            onSelect(station)
                        },
                        onEdit: {
                            onEdit(station)
                        },
                        onDelete: {
                            onDelete(station)
                        }
                    )
                }
            }

            if !canAddStation {
                Text(L10n.stationsLimitReachedDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func indicator(for station: Station) -> StationRow.Indicator? {
        guard selectedStationID == station.id else {
            return nil
        }

        if isLoadingStation {
            return .loading
        }

        if isPlaying {
            return .playing
        }

        return nil
    }
}
