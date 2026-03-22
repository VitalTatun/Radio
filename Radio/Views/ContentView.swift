import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var radioPlayer: RadioPlayer

    @State private var isShowingAddStationForm = false
    @State private var editingStation: Station?
    @State private var listMode: ListMode = .stations
    @State private var newStationName = ""
    @State private var newStationURL = ""
    @State private var showValidationError = false
    @State private var hoveredStationID: Station.ID?

    private enum ListMode {
        case stations
        case history
    }

    private enum StationListState {
        case canAdd
        case limitReached
    }

    private let listToolbarButtonHeight: CGFloat = 24
    private let listToolbarButtonWidth: CGFloat = 28

    private var stationListState: StationListState {
        radioPlayer.stations.count < 15 ? .canAdd : .limitReached
    }

    private var listSectionTitle: LocalizedStringResource {
        switch listMode {
        case .stations:
            L10n.sectionStations
        case .history:
            L10n.sectionHistory
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(radioPlayer.selectedStation?.name ?? L10n.string(L10n.stationNoneSelected))
                        .font(.headline)
                        .lineLimit(1)
                    Text(radioPlayer.statusText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    radioPlayer.togglePlayback()
                } label: {
                    Image(systemName: radioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(radioPlayer.isPlaying ? L10n.string(L10n.actionPause) : L10n.string(L10n.actionPlay))

                Button {
                    radioPlayer.restartCurrentStation()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(L10n.string(L10n.actionRestartStream))
            }

            nowPlayingSection
            volumeSection

            Divider()

            HStack {
                Text(listSectionTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    toggleListMode()
                } label: {
                    listToolbarButtonLabel(
                        systemName: listMode == .history ? "dot.radiowaves.left.and.right" : "music.note.list"
                    )
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(L10n.string(L10n.actionHistory))

                if case .history = listMode {
                    Button {
                        radioPlayer.clearTrackHistory()
                    } label: {
                        listToolbarButtonLabel(systemName: "trash")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(L10n.string(L10n.actionClearHistory))
                    .disabled(radioPlayer.trackHistory.isEmpty)
                }

                if case .stations = listMode {
                    switch stationListState {
                    case .canAdd:
                        Button {
                            beginAddingStation()
                        } label: {
                            listToolbarButtonLabel(systemName: "plus")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .help(L10n.string(L10n.actionAddStation))
                    case .limitReached:
                        Text(L10n.stationsLimitReached)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            switch listMode {
            case .stations:
                if radioPlayer.stations.isEmpty {
                    Text(L10n.stationsEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(radioPlayer.stations) { station in
                            Button {
                                radioPlayer.selectStation(station)
                            } label: {
                                HStack(spacing: 6) {
                                    Group {
                                        if let indicatorSymbol = stationIndicatorSymbol(for: station) {
                                            if indicatorSymbol == "circle.dashed" {
                                                Image(systemName: indicatorSymbol)
                                                    .contentTransition(.symbolEffect(.replace))
                                                    .symbolEffect(.rotate, options: .repeating)
                                            } else {
                                                Image(systemName: indicatorSymbol)
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
                                        .fill(hoveredStationID == station.id ? Color.secondary.opacity(0.15) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                            .onHover { isHovering in
                                hoveredStationID = isHovering ? station.id : nil
                            }
                            .contextMenu {
                                Button(L10n.actionEdit) {
                                    beginEditingStation(station)
                                }

                                Button(role: .destructive) {
                                    radioPlayer.deleteStation(station)
                                } label: {
                                    Text(L10n.actionDelete)
                                }
                            }
                        }
                    }

                    if case .limitReached = stationListState {
                        Text(L10n.stationsLimitReachedDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            case .history:
                if radioPlayer.trackHistory.isEmpty {
                    Text(L10n.historyEmpty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(radioPlayer.trackHistory) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Group {
                                    if let artworkData = item.artworkData,
                                       let artwork = NSImage(data: artworkData) {
                                        Image(nsImage: artwork)
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
                                        .foregroundStyle(.secondary)
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
                }
            }

            if isShowingAddStationForm,
               case .canAdd = stationListState,
               case .stations = listMode {
                addStationForm
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var nowPlayingSection: some View {
        HStack(spacing: 10) {
            Group {
                if let artwork = radioPlayer.nowPlayingArtwork {
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
                Text(radioPlayer.nowPlayingTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(radioPlayer.nowPlayingArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(5)
        .background(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 15))

    }

    private var volumeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(radioPlayer.volume) },
                    set: { radioPlayer.volume = Float($0) }
                ),
                in: 0...1
            )

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(L10n.string(L10n.playerVolume))
    }

    private var addStationForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.stationNamePlaceholder, text: $newStationName)
            TextField("https://example.com/stream", text: $newStationURL)

            if showValidationError {
                Text(L10n.stationValidationError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button(L10n.actionCancel) {
                    isShowingAddStationForm = false
                    clearAddStationForm()
                }

                Spacer()

                Button(editingStation == nil ? L10n.string(L10n.actionAdd) : L10n.string(L10n.actionSave)) {
                    let wasSuccessful: Bool

                    if let editingStation {
                        wasSuccessful = radioPlayer.updateStation(editingStation, name: newStationName, urlString: newStationURL)
                    } else {
                        wasSuccessful = radioPlayer.addStation(name: newStationName, urlString: newStationURL)
                    }

                    if wasSuccessful {
                        isShowingAddStationForm = false
                        clearAddStationForm()
                    } else {
                        showValidationError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editingStation == nil && stationListState == .limitReached)
            }
        }
    }

    private func beginAddingStation() {
        guard case .canAdd = stationListState else { return }
        listMode = .stations
        editingStation = nil
        showValidationError = false

        if isShowingAddStationForm {
            isShowingAddStationForm = false
            clearAddStationForm()
        } else {
            clearAddStationForm()
            isShowingAddStationForm = true
        }
    }

    private func beginEditingStation(_ station: Station) {
        listMode = .stations
        editingStation = station
        showValidationError = false
        newStationName = station.name
        newStationURL = station.url.absoluteString
        isShowingAddStationForm = true
    }

    private func clearAddStationForm() {
        showValidationError = false
        editingStation = nil
        newStationName = ""
        newStationURL = ""
    }

    private func toggleListMode() {
        listMode = listMode == .stations ? .history : .stations
    }

    private func listToolbarButtonLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: listToolbarButtonWidth, height: listToolbarButtonHeight)
    }

    private func stationIndicatorSymbol(for station: Station) -> String? {
        guard radioPlayer.selectedStationID == station.id else {
            return nil
        }

        if radioPlayer.isLoadingStation {
            return "circle.dashed"
        }

        if radioPlayer.isPlaying {
            return "play.fill"
        }

        return nil
    }
}

#Preview {
    ContentView()
        .environmentObject(RadioPlayer())
}
