import AVFoundation
import SwiftUI

struct PlaybackInfo {
    var currentTime: Double = 0
    var duration: Double = 0
    var isPaused = false
    /// Player controls (scrubber, buttons). Auto-hide after 3 s while playing.
    var controlsVisible = true

    var progress: Double { duration > 0 ? currentTime / duration : 0 }
}

/// One full-screen episode page: plays while active, tap toggles play/pause and controls,
/// and hands the overlay the playback state plus a seek action.
struct EpisodePlayerView<Overlay: View>: View {
    let player: AVPlayer
    let isActive: Bool
    var loops = false
    var onFinished: () -> Void = {}
    @ViewBuilder var content: (PlaybackInfo, _ seek: @escaping (Double) -> Void) -> Overlay

    @State private var info = PlaybackInfo()
    @State private var lastInteraction = Date()

    var body: some View {
        ZStack {
            VideoSurface(player: player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { togglePause() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(info.isPaused ? "Play" : "Pause")

            if info.isPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            content(info) { seek(to: $0) }
        }
        .onAppear { updatePlayback() }
        .onChange(of: isActive) { updatePlayback() }
        .onDisappear { player.pause() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
            guard isActive, (note.object as? AVPlayerItem) === player.currentItem else { return }
            if loops {
                player.seek(to: .zero)
                player.play()
            } else {
                onFinished()
            }
        }
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                if let item = player.currentItem, item.duration.isNumeric {
                    info.duration = item.duration.seconds
                }
                info.currentTime = player.currentTime().seconds
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        .task(id: lastInteraction) {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !info.isPaused else { return }
            withAnimation(.easeOut(duration: 0.25)) { info.controlsVisible = false }
        }
    }

    private func updatePlayback() {
        if isActive {
            info.isPaused = false
            info.controlsVisible = true
            lastInteraction = .now
            player.play()
        } else {
            player.pause()
        }
    }

    private func togglePause() {
        withAnimation(.easeOut(duration: 0.2)) {
            info.isPaused.toggle()
            info.controlsVisible = true
        }
        lastInteraction = .now
        if info.isPaused {
            player.pause()
        } else {
            player.play()
        }
    }

    private func seek(to seconds: Double) {
        info.currentTime = seconds
        lastInteraction = .now
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
