import SwiftUI

/// "For You": vertical swipe through the first episode of each series.
struct FeedView: View {
    @Environment(AppModel.self) private var app

    @State private var currentID: String?
    @State private var openSeries: SeriesSelection?
    @State private var episodesFor: Series?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.bgBase.ignoresSafeArea()

            switch app.catalogState {
            case .failed(let message):
                LoadErrorView(message: message) { Task { await app.reloadCatalog() } }
            case .loaded:
                feed
            default:
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            header
        }
        .fullScreenCover(item: $openSeries) { selection in
            SeriesPlayerView(series: selection.series, startEpisode: selection.episode)
        }
        .sheet(item: $episodesFor) { series in
            EpisodesSheet(series: series, current: nil) { number in
                episodesFor = nil
                openSeries = SeriesSelection(series: series, episode: number)
            }
        }
    }

    private var feed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(app.allSeries) { series in
                    if let first = series.episodes.first {
                        EpisodePlayerView(
                            player: app.players.player(for: first),
                            isActive: isActive(series),
                            loops: true
                        ) { info, _ in
                            FeedOverlay(
                                series: series,
                                progress: info.progress,
                                onWatch: { openSeries = SeriesSelection(series: series, episode: app.resumeEpisode(for: series)) },
                                onEpisodes: { episodesFor = series }
                            )
                        }
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(series.id)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if currentID == nil { currentID = app.allSeries.first?.id }
        }
        .onChange(of: currentID) { preloadNeighbours() }
    }

    private var header: some View {
        HStack {
            Text("For You")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) {
                    Capsule().fill(.white).frame(width: 20, height: 3).offset(y: 6)
                }
            Spacer()
            CoinBadge()
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, 4)
    }

    private func isActive(_ series: Series) -> Bool {
        currentID == series.id
            && app.selectedTab == .forYou
            && openSeries == nil
            && episodesFor == nil
            && !app.shopPresented
    }

    private func preloadNeighbours() {
        guard let currentID, let index = app.allSeries.firstIndex(where: { $0.id == currentID }) else { return }
        let next = app.allSeries.dropFirst(index + 1).prefix(2).compactMap(\.episodes.first)
        app.players.preload(next)
    }
}

private struct FeedOverlay: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let progress: Double
    let onWatch: () -> Void
    let onEpisodes: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Theme.Gradients.scrimTop
                .frame(height: 150)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Theme.Gradients.scrimBottom
                    .frame(height: 420)
                    .allowsHitTesting(false)
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 12) {
                        info
                        Spacer(minLength: 0)
                        rail
                    }
                    Button(action: onWatch) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Watch series · \(series.episodeCount) episodes")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.bottom, 16)
            }
            ProgressLine(value: progress, height: 2)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(series.genres, id: \.self) { VideoChip(text: $0) }
            }
            Text(series.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(series.synopsis)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)
        }
        .shadow(color: .black.opacity(0.4), radius: 4)
    }

    private var rail: some View {
        let liked = app.library.isLiked(series.id)
        let saved = app.library.isFavorite(series.id)
        return VStack(spacing: 20) {
            RailButton(
                systemImage: "heart.fill",
                label: (series.views / 40 + (liked ? 1 : 0)).compactFormatted,
                tint: liked ? Theme.Colors.accent : .white
            ) {
                app.library.toggleLike(series.id)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: liked)
            RailButton(
                systemImage: saved ? "bookmark.fill" : "bookmark",
                label: saved ? "Saved" : "Save",
                tint: saved ? Theme.Colors.coin : .white
            ) {
                app.library.toggleFavorite(series.id)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: saved)
            RailButton(systemImage: "list.bullet", label: "\(series.episodeCount) eps", action: onEpisodes)
            ShareLink(item: "Watch \"\(series.title)\" on Cliffzy") {
                RailLabel(systemImage: "square.and.arrow.up", label: "Share")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
        }
    }
}

struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(CapsuleButtonStyle())
        }
    }
}
