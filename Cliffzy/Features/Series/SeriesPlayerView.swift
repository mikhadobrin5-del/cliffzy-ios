import SwiftUI

/// Full-screen series player: swipe up for the next episode, locked episodes show the paywall.
struct SeriesPlayerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    let series: Series
    let startEpisode: Int

    @State private var currentNumber: Int?
    @State private var showEpisodes = false
    @State private var paywallEpisode: Episode?

    var body: some View {
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
        .background(.black)
        .overlay(alignment: .top) { topBar }
        .onAppear {
            if currentNumber == nil { currentNumber = startEpisode }
        }
        .onChange(of: currentNumber) { episodeDidChange() }
        .sheet(isPresented: $showEpisodes) {
            EpisodeGridSheet(series: series, current: currentNumber ?? 1) { number in
                showEpisodes = false
                withAnimation { currentNumber = number }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $paywallEpisode) { episode in
            PaywallSheet(episode: episode)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private func page(for episode: Episode) -> some View {
        let access = app.entitlements.access(for: episode)
        if access.isPlayable {
            EpisodePlayerView(
                player: app.players.player(for: episode),
                isActive: currentNumber == episode.number && paywallEpisode == nil && !showEpisodes,
                onFinished: { advance(from: episode) }
            ) {
                EmptyView()
            }
        } else {
            LockedEpisodeView(series: series, episode: episode) {
                paywallEpisode = episode
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                app.players.pauseAll()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.bold())
                    .padding(10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(series.title).font(.subheadline.bold()).lineLimit(1)
                Text("Episode \(currentNumber ?? startEpisode) of \(series.episodeCount)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                showEpisodes = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .padding(10)
            }
            .accessibilityLabel("Episodes")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .background(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func episodeDidChange() {
        guard let number = currentNumber, let episode = series.episode(number: number) else { return }
        app.players.pauseAll(except: episode.id)
        if app.entitlements.access(for: episode).isPlayable {
            app.library.recordWatched(seriesID: series.id, episodeNumber: number)
        } else {
            paywallEpisode = episode
        }
        let upcoming = series.episodes
            .filter { $0.number > number && app.entitlements.access(for: $0).isPlayable }
            .prefix(2)
        app.players.preload(Array(upcoming))
    }

    private func advance(from episode: Episode) {
        guard episode.number < series.episodeCount else { return }
        withAnimation { currentNumber = episode.number + 1 }
    }
}

private struct LockedEpisodeView: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let episode: Episode
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            PosterView(series: series)
                .blur(radius: 30)
                .overlay(Color.black.opacity(0.5))
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                Text("Episode \(episode.number) is locked")
                    .font(.headline)
                Button(action: onUnlock) {
                    Text("Unlock for \(app.entitlements.config.episodePriceCoins) coins")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.pink, in: Capsule())
                }
            }
            .foregroundStyle(.white)
        }
    }
}

private struct EpisodeGridSheet: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let current: Int
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(series.episodes) { episode in
                        Button {
                            onSelect(episode.number)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Text("\(episode.number)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(
                                        episode.number == current ? Color.pink.opacity(0.35) : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                if !app.entitlements.access(for: episode).isPlayable {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .padding(4)
                                }
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding()
            }
            .navigationTitle(series.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
