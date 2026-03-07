import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var radioPlayer: RadioPlayer

    @State private var isShowingAddStationForm = false
    @State private var editingStation: Station?
    @State private var newStationName = ""
    @State private var newStationURL = ""
    @State private var showValidationError = false
    @State private var hoveredStationID: Station.ID?

    private enum StationListState {
        case canAdd
        case limitReached
    }

    private var stationListState: StationListState {
        radioPlayer.stations.count < 15 ? .canAdd : .limitReached
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(radioPlayer.selectedStation?.name ?? "Станция не выбрана")
                    .font(.headline)
                    .lineLimit(1)

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
                .help(radioPlayer.isPlaying ? "Пауза" : "Плей")

                Button {
                    radioPlayer.restartCurrentStation()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Перезапустить поток")
            }

            nowPlayingSection
            volumeSection

            Divider()

            HStack {
                Text("Станции")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                switch stationListState {
                case .canAdd:
                    Button {
                        beginAddingStation()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glass)
                    .help("Добавить станцию")
                case .limitReached:
                    Text("Достигнут лимит 15 станций")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if radioPlayer.stations.isEmpty {
                Text("Пока нет станций")
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
                            Button("Редактировать") {
                                beginEditingStation(station)
                            }

                            Button(role: .destructive) {
                                radioPlayer.deleteStation(station)
                            } label: {
                                Text("Удалить")
                            }
                        }
                    }
                }

                if case .limitReached = stationListState {
                    Text("Вы достигли максимума: 15 станций")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isShowingAddStationForm, case .canAdd = stationListState {
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
                Text(radioPlayer.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
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
        .help("Громкость")
    }

    private var addStationForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Название", text: $newStationName)
            TextField("https://example.com/stream", text: $newStationURL)

            if showValidationError {
                Text("Введите корректные название и URL (http/https).")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Отмена") {
                    isShowingAddStationForm = false
                    clearAddStationForm()
                }

                Spacer()

                Button(editingStation == nil ? "Добавить" : "Сохранить") {
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
