import AVFoundation
import SwiftUI

/// One full-screen episode page: plays while active, tap to pause, reports the end.
struct EpisodePlayerView<Overlay: View>: View {
    let player: AVPlayer
    let isActive: Bool
    var loops = false
    var onFinished: () -> Void = {}
    @ViewBuilder var overlay: () -> Overlay

    @State private var isPaused = false
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            VideoSurface(player: player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { togglePause() }

            if isPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.85))
                    .allowsHitTesting(false)
            }

            overlay()

            VStack {
                Spacer()
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
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
                if let item = player.currentItem, item.duration.isNumeric, item.duration.seconds > 0 {
                    progress = player.currentTime().seconds / item.duration.seconds
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func updatePlayback() {
        if isActive {
            isPaused = false
            player.play()
        } else {
            player.pause()
        }
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            player.pause()
        } else {
            player.play()
        }
    }
}
