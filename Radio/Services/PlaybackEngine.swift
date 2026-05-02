import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackEngine {
    enum Event {
        case timeControlPaused
        case timeControlWaiting
        case timeControlPlaying
        case timeControlUnknown
        case itemReadyToPlay(asset: AVAsset, stationID: Station.ID?)
        case itemFailed(error: NSError?, asset: AVAsset)
        case metadata([AVMetadataItem])
    }

    var onEvent: ((Event) -> Void)?

    private let player = AVPlayer()
    private let metadataOutputDelegate = MetadataOutputDelegate()
    private var cancellables = Set<AnyCancellable>()
    private var itemStatusCancellable: AnyCancellable?
    private var metadataOutput: AVPlayerItemMetadataOutput?

    init() {
        metadataOutputDelegate.onMetadata = { [weak self] metadataItems in
            self?.onEvent?(.metadata(metadataItems))
        }

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                switch status {
                case .paused:
                    self.onEvent?(.timeControlPaused)
                case .waitingToPlayAtSpecifiedRate:
                    self.onEvent?(.timeControlWaiting)
                case .playing:
                    self.onEvent?(.timeControlPlaying)
                @unknown default:
                    self.onEvent?(.timeControlUnknown)
                }
            }
            .store(in: &cancellables)
    }

    var timeControlStatus: AVPlayer.TimeControlStatus {
        player.timeControlStatus
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    func currentAssetURL() -> URL? {
        (player.currentItem?.asset as? AVURLAsset)?.url
    }

    func pause() {
        player.pause()
    }

    func clearCurrentItem() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func playCurrentItem() {
        player.play()
    }

    func replaceCurrentItem(with url: URL, stationID: Station.ID?) {
        let item = AVPlayerItem(url: url)
        observe(item: item, stationID: stationID)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func observe(item: AVPlayerItem, stationID: Station.ID?) {
        if let metadataOutput {
            player.currentItem?.remove(metadataOutput)
        }

        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(metadataOutputDelegate, queue: .main)
        item.add(metadataOutput)
        self.metadataOutput = metadataOutput

        itemStatusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                switch status {
                case .unknown:
                    break
                case .readyToPlay:
                    self.onEvent?(.itemReadyToPlay(asset: item.asset, stationID: stationID))
                case .failed:
                    self.onEvent?(.itemFailed(error: item.error as NSError?, asset: item.asset))
                @unknown default:
                    self.onEvent?(.itemFailed(error: nil, asset: item.asset))
                }
            }
    }
}
