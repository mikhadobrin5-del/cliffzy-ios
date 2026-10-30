import SwiftUI

/// Full-screen series player: swipe up for the next episode; locked episodes show an unlock card.
struct SeriesPlayerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let series: Series
    let startEpisode: Int

    @State private var currentNumber: Int?
    @State private var showEpisodes = false
    @State private var paywallEpisode: Episode?
    @State private var unlockedCount = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            pager
            topBar
        }
        .statusBarHidden(false)
        .onAppear {
            if currentNumber == nil { currentNumber = startEpisode }
        }
        .onChange(of: currentNumber) { episodeDidChange() }
        .sensoryFeedback(.selection, trigger: currentNumber)
        .sensoryFeedback(.success, trigger: unlockedCount)
        .sheet(isPresented: $showEpisodes) {
            EpisodesSheet(series: series, current: currentNumber) { number in
                showEpisodes = false
                move(to: number)
            }
        }
        .sheet(item: $paywallEpisode) { episode in
            PaywallSheet(episode: episode)
        }
    }

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(series.episodes) { episode in
                    page(for: episode)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(episode.number)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentNumber)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func page(for episode: Episode) -> some View {
        if app.entitlements.access(for: episode).isPlayable {
            EpisodePlayerView(
                player: app.players.player(for: episode),
                isActive: currentNumber == episode.number && paywallEpisode == nil && !showEpisodes,
                onFinished: { advance(from: episode) }
            ) { info, seek in
                PlayerControls(series: series, episode: episode, info: info, seek: seek) {
                    advance(from: episode)
                }
            }
        } else {
            LockedEpisodeView(series: series, episode: episode) {
                tryUnlock(episode)
            } onVIP: {
                paywallEpisode = episode
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                app.players.pauseAll()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(series.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("Episode \(currentNumber ?? startEpisode) of \(series.episodeCount)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                showEpisodes = true
            } label: {
                Image(systemName: "rectangle.stack")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Episodes")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .background(alignment: .top) {
            Theme.Gradients.scrimTop
                .frame(height: 150)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func tryUnlock(_ episode: Episode) {
        do {
            try app.entitlements.unlock(episode)
            unlockedCount += 1
            app.library.recordWatched(seriesID: series.id, episodeNumber: episode.number)
        } catch {
            paywallEpisode = episode
        }
    }

    private func episodeDidChange() {
        guard let number = currentNumber, let episode = series.episode(number: number) else { return }
        app.players.pauseAll(except: episode.id)
        if app.entitlements.access(for: episode).isPlayable {
            app.library.recordWatched(seriesID: series.id, episodeNumber: number)
        }
        let upcoming = series.episodes
            .filter { $0.number > number && app.entitlements.access(for: $0).isPlayable }
            .prefix(2)
        app.players.preload(Array(upcoming))
    }

    private func advance(from episode: Episode) {
        guard episode.number < series.episodeCount else { return }
        move(to: episode.number + 1)
    }

    private func move(to number: Int) {
        if reduceMotion {
            currentNumber = number
        } else {
            withAnimation { currentNumber = number }
        }
    }
}

/// Right rail, episode title, scrubber, times and "Next episode" over the video.
private struct PlayerControls: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let episode: Episode
    let info: PlaybackInfo
    let seek: (Double) -> Void
    let onNext: () -> Void

    @State private var scrubValue: Double?

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                rail
            }
            .padding(.horizontal, Theme.Spacing.margin)
            if info.controlsVisible || info.isPaused {
                bottomControls
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            Theme.Gradients.scrimBottom
                .frame(height: 260)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var rail: some View {
        let liked = app.library.isLiked(series.id)
        let saved = app.library.isFavorite(series.id)
        return VStack(spacing: 20) {
            RailButton(systemImage: "heart.fill", label: liked ? "Liked" : "Like", tint: liked ? Theme.Colors.accent : .white) {
                app.library.toggleLike(series.id)
            }
            RailButton(systemImage: saved ? "bookmark.fill" : "bookmark", label: saved ? "Saved" : "Save", tint: saved ? Theme.Colors.coin : .white) {
                app.library.toggleFavorite(series.id)
            }
            ShareLink(item: "Watch \"\(series.title)\" episode \(episode.number) on Cliffzy") {
                RailLabel(systemImage: "square.and.arrow.up", label: "Share")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
        }
        .padding(.bottom, 12)
    }

    private var bottomControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(episode.title)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Slider(
                value: Binding(
                    get: { scrubValue ?? info.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(info.duration, 1),
                onEditingChanged: { editing in
                    if !editing, let value = scrubValue {
                        seek(value)
                        scrubValue = nil
                    }
                }
            )
            .tint(Theme.Colors.accent)
            .accessibilityLabel("Playback position")
            HStack {
                Text("\((scrubValue ?? info.currentTime).clockFormatted) / \(info.duration.clockFormatted)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if episode.number < series.episodeCount {
                    Button(action: onNext) {
                        HStack(spacing: 4) {
                            Text("Next: Episode \(episode.number + 1)")
                            Image(systemName: "chevron.right")
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
    }
}

/// Dimmed backdrop with the unlock card (screen 03).
private struct LockedEpisodeView: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let episode: Episode
    let onUnlock: () -> Void
    let onVIP: () -> Void

    var body: some View {
        let price = app.entitlements.config.episodePriceCoins
        let short = app.entitlements.coinsNeeded(for: episode)
        ZStack {
            PosterBackdrop(series: series)
                .overlay(Color.black.opacity(0.7))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.Colors.accent.opacity(0.18))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .frame(width: 68, height: 68)

                Text("Episode \(episode.number) is locked")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("The first \(app.entitlements.config.freeEpisodes) episodes are free. Unlock to find out what happens next.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack {
                    Text("Your balance")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    CoinBadge()
                }
                .padding(.vertical, 4)

                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Text("Unlock for \(price)")
                        CoinIcon(size: 18)
                    }
                }
                .buttonStyle(.cliffzy(.coin))

                Button(action: onVIP) {
                    Label("Get VIP · all episodes", systemImage: "crown.fill")
                }
                .buttonStyle(.cliffzy(.vip))

                Text(short > 0 ? "You need \(short) more coins. Tap to pick a pack." : "Coins are spent once; the episode stays unlocked.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Theme.Colors.bgSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.Colors.borderSubtle))
            .padding(.horizontal, 24)
        }
    }
}
