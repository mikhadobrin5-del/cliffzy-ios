import SwiftUI

/// "For You": vertical swipe through the first episode of each series.
struct FeedView: View {
    @Environment(AppModel.self) private var app

    @State private var items: [Series] = []
    @State private var currentID: String?
    @State private var openSeries: Series?
    @State private var loadError: String?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { series in
                    if let first = series.episodes.first {
                        EpisodePlayerView(
                            player: app.players.player(for: first),
                            isActive: currentID == series.id && openSeries == nil,
                            loops: true
                        ) {
                            FeedOverlay(series: series) { openSeries = series }
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
        .background(.black)
        .overlay {
            if let loadError {
                ContentUnavailableView("Couldn't load", systemImage: "wifi.exclamationmark", description: Text(loadError))
            } else if items.isEmpty {
                ProgressView()
            }
        }
        .task {
            guard items.isEmpty else { return }
            do {
                items = try await app.catalog.feed()
                currentID = items.first?.id
            } catch {
                loadError = error.localizedDescription
            }
        }
        .onChange(of: currentID) { preloadNeighbours() }
        .fullScreenCover(item: $openSeries) { series in
            SeriesPlayerView(series: series, startEpisode: 1)
        }
    }

    private func preloadNeighbours() {
        guard let currentID, let index = items.firstIndex(where: { $0.id == currentID }) else { return }
        let next = items.dropFirst(index + 1).prefix(2).compactMap(\.episodes.first)
        app.players.preload(next)
    }
}

private struct FeedOverlay: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let onWatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(series.title)
                        .font(.title3.bold())
                    Text(series.synopsis)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                    Text(series.genres.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 16)
                Button {
                    app.library.toggleFavorite(series.id)
                } label: {
                    Image(systemName: app.library.isFavorite(series.id) ? "bookmark.fill" : "bookmark")
                        .font(.title2)
                }
                .accessibilityLabel("Add to My List")
            }
            Button(action: onWatch) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Watch series · \(series.episodeCount) episodes")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
                .allowsHitTesting(false)
        }
    }
}
