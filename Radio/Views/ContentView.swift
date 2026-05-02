import SwiftUI

struct ContentView: View {
    @Environment(RadioPlayer.self) private var radioPlayer
    @State private var viewModel = ContentViewModel()

    var body: some View {
        let screenState = viewModel.makeScreenState(from: radioPlayer)

        VStack(alignment: .leading, spacing: 12) {
            PlaybackHeaderView(
                stationName: screenState.stationName,
                statusText: screenState.statusText,
                isPlaying: screenState.isPlaying,
                canRestart: screenState.canRestartCurrentStation,
                onTogglePlayback: {
                    radioPlayer.togglePlayback()
                },
                onRestart: {
                    radioPlayer.restartCurrentStation()
                }
            )

            NowPlayingSection(
                artwork: screenState.nowPlayingArtwork,
                title: screenState.nowPlayingTitle,
                artist: screenState.nowPlayingArtist,
                isPlaying: screenState.isPlaying
            )

            VolumeSection(
                volume: Binding(
                    get: { Double(radioPlayer.volume) },
                    set: { radioPlayer.volume = Float($0) }
                )
            )

            Divider()

            ListToolbarView(
                sectionTitle: viewModel.listSectionTitle,
                listMode: viewModel.listMode,
                canAddStation: screenState.canAddStation,
                isTrackHistoryEmpty: screenState.isTrackHistoryEmpty,
                onToggleListMode: {
                    viewModel.toggleListMode()
                },
                onClearHistory: {
                    radioPlayer.clearTrackHistory()
                },
                onAddStation: {
                    viewModel.beginAddingStation(canAddStation: screenState.canAddStation)
                }
            )

            if viewModel.isShowingStations {
                StationListSection(
                    stations: screenState.stations,
                    selectedStationID: screenState.selectedStationID,
                    isLoadingStation: screenState.isLoadingStation,
                    isPlaying: screenState.isPlaying,
                    hoveredStationID: $viewModel.hoveredStationID,
                    canAddStation: screenState.canAddStation,
                    onSelect: { station in
                        radioPlayer.selectStation(station)
                    },
                    onEdit: { station in
                        viewModel.beginEditingStation(station)
                    },
                    onDelete: { station in
                        radioPlayer.deleteStation(station)
                    }
                )
            } else {
                TrackHistoryListSection(items: screenState.trackHistory)
            }

            if viewModel.shouldShowStationForm {
                StationFormView(
                    stationName: $viewModel.stationName,
                    stationURL: $viewModel.stationURL,
                    isEditing: viewModel.isEditingStation,
                    showValidationError: viewModel.showValidationError,
                    canSubmit: viewModel.canSubmitStationForm(canAddStation: screenState.canAddStation),
                    onCancel: {
                        viewModel.cancelStationForm()
                    },
                    onSubmit: {
                        viewModel.submitStationForm(using: radioPlayer)
                    }
                )
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

#Preview {
    ContentView()
        .environment(RadioPlayer())
}
