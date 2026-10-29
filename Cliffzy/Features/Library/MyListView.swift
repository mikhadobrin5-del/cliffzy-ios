import SwiftUI

struct MyListView: View {
    @Environment(AppModel.self) private var app

    @State private var allSeries: [Series] = []
    @State private var selection: SeriesSelection?

    var body: some View {
        NavigationStack {
            List {
                Section("Saved") {
                    if favorites.isEmpty {
                        Text("Tap the bookmark on any series to save it here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(favorites) { row($0) }
                }
                Section("History") {
                    ForEach(history) { row($0) }
                }
            }
            .navigationTitle("My List")
            .task {
                guard allSeries.isEmpty else { return }
                allSeries = (try? await app.catalog.feed()) ?? []
            }
            .fullScreenCover(item: $selection) { selection in
                SeriesPlayerView(series: selection.series, startEpisode: selection.episode)
            }
        }
    }

    private var favorites: [Series] {
        app.library.favoriteSeriesIDs.compactMap(series(id:))
    }

    private var history: [Series] {
        app.library.recentSeriesIDs.compactMap(series(id:))
    }

    private func series(id: String) -> Series? {
        allSeries.first { $0.id == id }
    }

    private func row(_ series: Series) -> some View {
        let last = app.library.lastEpisode[series.id] ?? 1
        return Button {
            selection = SeriesSelection(series: series, episode: last)
        } label: {
            HStack(spacing: 12) {
                PosterView(series: series)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.title).font(.body.bold())
                    Text("Episode \(last) of \(series.episodeCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
