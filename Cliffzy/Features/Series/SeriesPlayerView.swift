import SwiftUI

/// Full-screen series player: swipe up for the next episode; locked episodes show the VIP card.
/// Opened from a card, it first loads the episode list with access rules from the server.
struct SeriesPlayerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let series: Series
    let startEpisode: Int
    var showsEpisodesOnAppear = false

    @State private var loaded: Series?
    @State private var loadError: String?
    @State private var currentNumber: Int?
    @State private var showEpisodes = false
    @State private var paywallEpisode: Episode?
    @AppStorage("settings.autoplay") private var autoplay = true

    private var shown: Series { loaded ?? series }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if shown.hasEpisodes {
                pager
            } else if let loadError {
                LoadErrorView(message: loadError) { Task { await load() } }
            } else {
                PosterBackdrop(series: shown)
                    .ignoresSafeArea()
                    .overlay { ProgressView().tint(.white) }
            }
            topBar
        }
        .statusBarHidden(false)
        .task { await load() }
        .onChange(of: currentNumber) { oldValue, _ in episodeDidChange(from: oldValue) }
        .onChange(of: app.account.isVIP) {
            if app.account.isVIP { paywallEpisode = nil }
        }
        .onDisappear { saveProgress(of: currentNumber) }
        .sensoryFeedback(.selection, trigger: currentNumber)
        .sensoryFeedback(.success, trigger: app.account.isVIP)
        .sheet(isPresented: $showEpisodes) {
            EpisodesSheet(series: shown, current: currentNumber) { number in
                showEpisodes = false
                move(to: number)
            }
        }
        .sheet(item: $paywallEpisode) { episode in
            PaywallSheet(episode: episode)
        }
    }

    private func load() async {
        loadError = nil
        do {
            let detailed = try await app.detailedSeries(series, refresh: !series.hasEpisodes)
            loaded = detailed
            if currentNumber == nil {
                currentNumber = min(max(startEpisode, 1), max(detailed.episodeCount, 1))
            }
            if showsEpisodesOnAppear { showEpisodes = true }
        } catch {
            if !shown.hasEpisodes { loadError = error.localizedDescription }
        }
    }

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(shown.episodes) { episode in
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
        if app.access(for: episode).isPlayable {
            EpisodePlayerView(
                player: app.players.player(for: episode),
                isActive: currentNumber == episode.number && paywallEpisode == nil && !showEpisodes,
                backdrop: shown,
                onFinished: { if autoplay { advance(from: episode) } }
            ) { info, seek in
                PlayerControls(series: shown, episode: episode, info: info, seek: seek) {
                    advance(from: episode)
                }
            }
        } else {
            LockedEpisodeView(series: shown, episode: episode) {
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
                Text(shown.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("Episode \(currentNumber ?? startEpisode) of \(shown.episodeCount)")
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
            .disabled(!shown.hasEpisodes)
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

    private func episodeDidChange(from previous: Int?) {
        saveProgress(of: previous)
        guard let number = currentNumber, let episode = shown.episode(number: number) else { return }
        app.players.pauseAll(except: episode.id)
        if app.access(for: episode).isPlayable {
            app.library.recordWatched(seriesID: shown.id, episodeNumber: number)
        }
        let upcoming = shown.episodes
            .filter { $0.number > number && app.access(for: $0).isPlayable }
            .prefix(2)
        app.players.preload(Array(upcoming))
    }

    /// Where the viewer stopped in an episode, for Continue watching.
    private func saveProgress(of number: Int?) {
        guard let number, let episode = shown.episode(number: number), app.access(for: episode).isPlayable else { return }
        let position = app.players.position(of: episode)
        guard position.isFinite, position > 0 else { return }
        app.library.recordWatched(seriesID: shown.id, episodeNumber: number, positionSec: Int(position))
    }

    private func advance(from episode: Episode) {
        guard episode.number < shown.episodeCount else { return }
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
    let info: PlaybackState
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
            ShareLink(item: AppConfig.shareURL(for: series.id), message: Text("Watch \"\(series.title)\" episode \(episode.number) on Cliffzy")) {
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

/// Dimmed poster with the VIP card (screen 03).
private struct LockedEpisodeView: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let episode: Episode
    let onVIP: () -> Void

    var body: some View {
        ZStack {
            PosterBackdrop(series: series)
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.Colors.vip.opacity(0.18))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.Colors.vip)
                }
                .frame(width: 68, height: 68)

                Text("Episode \(episode.number) is for VIP")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(freeText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: onVIP) {
                    Label(priceText, systemImage: "crown.fill")
                }
                .buttonStyle(.cliffzy(.vip))

                Text("Every episode of every series. Cancel anytime in Settings.")
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

    private var freeText: String {
        guard let free = series.freeEpisodes, free > 0 else { return "Get VIP to keep watching." }
        return "The first \(free) episodes are free. Get VIP to find out what happens next."
    }

    private var priceText: String {
        guard let plan = app.purchases.plans.first else { return "Get VIP · all episodes" }
        return "Get VIP · \(plan.displayPrice) / \(plan.periodName)"
    }
}
