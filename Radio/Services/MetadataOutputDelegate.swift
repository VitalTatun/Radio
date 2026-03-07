import AVFoundation
import Foundation

final class MetadataOutputDelegate: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    var onMetadata: (([AVMetadataItem]) -> Void)?

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        for group in groups {
            onMetadata?(group.items)
        }
    }
}
