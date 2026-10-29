import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var app

    @State private var shelves: [Shelf] = []
    @State private var allSeries: [Series] = []
    @State private var selection: SeriesSelection?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if !continueWatching.isEmpty {
                        shelf(title: "Continue watching", series: continueWatching, resume: true)
                    }
                    ForEach(shelves) { shelf in
                        self.shelf(title: shelf.title, series: shelf.series, resume: false)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Discover")
            .task {
                guard shelves.isEmpty else { return }
                shelves = (try? await app.catalog.shelves()) ?? []
                allSeries = (try? await app.catalog.feed()) ?? []
            }
            .fullScreenCover(item: $selection) { selection in
                SeriesPlayerView(series: selection.series, startEpisode: selection.episode)
            }
        }
    }

    private var continueWatching: [Series] {
        app.library.recentSeriesIDs.compactMap { id in allSeries.first { $0.id == id } }
    }

    private func shelf(title: String, series: [Series], resume: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(series) { item in
                        Button {
                            let episode = resume ? (app.library.lastEpisode[item.id] ?? 1) : 1
                            selection = SeriesSelection(series: item, episode: episode)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                PosterView(series: item)
                                    .frame(width: 120)
                                if resume, let last = app.library.lastEpisode[item.id] {
                                    Text("Ep \(last) of \(item.episodeCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct SeriesSelection: Identifiable {
    let series: Series
    let episode: Int

    var id: String { "\(series.id)-\(episode)" }
}
